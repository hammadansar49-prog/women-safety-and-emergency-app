import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'social_controller.dart';

Future<String> prepareProfilePhoto(XFile file) async {
  if (await file.length() > 10 * 1024 * 1024) {
    throw StateError('Choose an image smaller than 10 MB.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  try {
    if (descriptor.width * descriptor.height > 40000000) {
      throw StateError('Choose a smaller image.');
    }
    final width = descriptor.width > descriptor.height
        ? 384
        : (384 * descriptor.width / descriptor.height).round().clamp(1, 384);
    final height = descriptor.height >= descriptor.width
        ? 384
        : (384 * descriptor.height / descriptor.width).round().clamp(1, 384);
    final codec = await descriptor.instantiateCodec(
      targetWidth: width,
      targetHeight: height,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        return base64Encode(data!.buffer.asUint8List());
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}

Widget profileAvatar(SocialController social, double radius) {
  final photo = social.photoFor(social.currentUserId);
  return CircleAvatar(
    radius: radius,
    backgroundImage: photo == null ? null : MemoryImage(base64Decode(photo)),
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
  String? error;
  Future<void> choose() async {
    final owner = widget.social.currentUserId;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final data = await prepareProfilePhoto(file);
      if (!mounted || owner != widget.social.currentUserId) return;
      widget.social.setPhoto(data);
      await widget.social.flush();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Photo could not be loaded or saved. Use a valid image under 10 MB and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      profileAvatar(widget.social, 44),
      TextButton.icon(
        onPressed: busy ? null : choose,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(busy ? 'Saving photo…' : 'Change photo'),
      ),
      if (widget.social.photoFor(widget.social.currentUserId) != null)
        TextButton(
          onPressed: busy ? null : () => widget.social.setPhoto(null),
          child: const Text('Remove photo'),
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
