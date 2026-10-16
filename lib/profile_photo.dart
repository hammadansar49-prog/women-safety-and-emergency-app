import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'social_controller.dart';
import 'photo_crop_screen.dart';
import 'photo_decoder.dart';

Future<String> prepareProfilePhoto(XFile file) async {
  final bytes = await file.readAsBytes();
  // Decode at thumbnail width. Encoded descriptor dimensions are unavailable on web.
  final decoded = await decodeProfileImage(bytes, targetWidth: 512);
  try {
    final source = decoded;
    final ratio =
        512 / (source.width > source.height ? source.width : source.height);
    final scale = ratio < 1 ? ratio : 1.0;
    final width = (source.width * scale).round().clamp(1, 512);
    final height = (source.height * scale).round().clamp(1, 512);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();
    try {
      final thumbnail = await picture.toImage(width, height);
      try {
        final data = await thumbnail.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (data == null) throw StateError('Image conversion failed.');
        return compute(_encodeProfileThumbnail, {
          'bytes': data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          'width': width,
          'height': height,
        });
      } finally {
        thumbnail.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    decoded.dispose();
  }
}

String _encodeProfileThumbnail(Map<String, Object> input) {
  final bytes = input['bytes'] as Uint8List;
  final image = img.Image.fromBytes(
    width: input['width'] as int,
    height: input['height'] as int,
    bytes: bytes.buffer,
    bytesOffset: bytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final png = img.encodePng(image);
  // Preserve transparency. For opaque photos choose the smaller encoding.
  if (image.any((pixel) => pixel.a < 255)) return base64Encode(png);
  final jpeg = img.encodeJpg(image, quality: 92);
  return base64Encode(jpeg.length < png.length ? jpeg : png);
}

Widget profileAvatar(SocialController social, double radius) {
  final photo = social.photoFor(social.currentUserId);
  return CircleAvatar(
    radius: radius,
    backgroundImage: photo == null
        ? null
        : ProfileMemoryImage(base64Decode(photo)),
    child: photo == null ? Text(social.currentUser.name.substring(0, 1)) : null,
  );
}

class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor({super.key, required this.social});
  final SocialController social;
  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  bool busy = false;
  bool pressed = false;
  String? error;
  Future<void> choose() async {
    final owner = widget.social.currentUserId;
    setState(() {
      busy = true;
      error = null;
    });
    var stage = 'picker';
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return;
      stage = 'image';
      final bytes = await file.readAsBytes();
      if (!mounted || owner != widget.social.currentUserId) return;
      final cropped = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => PhotoCropScreen(bytes: bytes)),
      );
      if (cropped == null) return;
      final data = await prepareProfilePhoto(XFile.fromData(cropped));
      if (!mounted || owner != widget.social.currentUserId) return;
      stage = 'save';
      widget.social.setPhoto(data);
      await widget.social.flush();
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = stage == 'save'
              ? 'Photo selected, but not saved. Check device storage and tap Retry above.'
              : stage == 'picker'
              ? 'Could not open photos. Please try again.'
              : exception is StateError
              ? exception.message
              : 'This image could not be read. Try a JPG, PNG or WebP photo.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showOptions() async {
    final owner = widget.social.currentUserId;
    final hasPhoto = widget.social.photoFor(owner) != null;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile photo'),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(hasPhoto ? 'Change photo' : 'Upload photo'),
                onTap: () => Navigator.pop(context, 'upload'),
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove photo'),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || owner != widget.social.currentUserId) return;
    if (action == 'upload') await choose();
    if (action == 'remove') {
      widget.social.setPhoto(null);
      setState(() => error = null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        button: true,
        label: 'Profile photo options',
        child: AnimatedScale(
          scale: pressed ? 0.90 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: InkWell(
            key: const ValueKey('profile-photo-button'),
            onHighlightChanged: (value) => setState(() => pressed = value),
            onTap: busy ? null : showOptions,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                profileAvatar(widget.social, 44),
                if (busy)
                  const SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Saving photo',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}

Future<void> recoverProfilePhoto(SocialController social) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final result = await ImagePicker().retrieveLostData();
  if (result.files?.isNotEmpty == true) {
    social.setPhoto(await prepareProfilePhoto(result.files!.first));
    await social.flush();
  }
}
