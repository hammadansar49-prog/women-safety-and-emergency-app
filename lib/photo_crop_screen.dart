import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'photo_decoder.dart';

Rect profileCropRect(Size image, double zoom, Offset offset) {
  final side = math.min(image.width, image.height) / zoom;
  final x = ((image.width - side) / 2 - offset.dx * side).clamp(
    0.0,
    image.width - side,
  );
  final y = ((image.height - side) / 2 - offset.dy * side).clamp(
    0.0,
    image.height - side,
  );
  return Rect.fromLTWH(x, y, side, side);
}

class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  ui.Image? image;
  double zoom = 1, startZoom = 1;
  Offset offset = Offset.zero,
      startOffset = Offset.zero,
      startPoint = Offset.zero;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final decoded = await decodeProfileImage(widget.bytes, targetWidth: 2048);
      if (!mounted) {
        decoded.dispose();
        return;
      }
      setState(() => image = decoded);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'This photo could not be opened. Please choose another image.',
        );
      }
    }
  }

  Size get imageSize => Size(image!.width.toDouble(), image!.height.toDouble());
  void constrainOffset() {
    final side = math.min(imageSize.width, imageSize.height) / zoom;
    final maxX = (imageSize.width / side - 1) / 2;
    final maxY = (imageSize.height / side - 1) / 2;
    offset = Offset(offset.dx.clamp(-maxX, maxX), offset.dy.clamp(-maxY, maxY));
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final rect = profileCropRect(imageSize, zoom, offset);
      final size = math.min(512, rect.width.round()).clamp(1, 512);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        image!,
        rect,
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      try {
        final cropped = await picture.toImage(size, size);
        try {
          final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw StateError('Could not crop photo');
          if (mounted) {
            Navigator.pop(
              context,
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            );
          }
        } finally {
          cropped.dispose();
        }
      } finally {
        picture.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not prepare photo. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crop photo')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameSize = math.min(
            360.0,
            math.min(
              constraints.maxWidth - 32,
              math.max(100.0, constraints.maxHeight - 210),
            ),
          );
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Drag to move. Pinch or use the slider to zoom.'),
                  const SizedBox(height: 16),
                  if (image == null && error == null)
                    const CircularProgressIndicator(),
                  if (image != null) ...[
                    Center(
                      child: GestureDetector(
                        onScaleStart: saving
                            ? null
                            : (details) {
                                startZoom = zoom;
                                startOffset = offset;
                                startPoint = details.localFocalPoint;
                              },
                        onScaleUpdate: saving
                            ? null
                            : (details) => setState(() {
                                zoom = (startZoom * details.scale).clamp(
                                  1.0,
                                  4.0,
                                );
                                offset =
                                    startOffset * (zoom / startZoom) +
                                    (details.localFocalPoint - startPoint) /
                                        frameSize;
                                constrainOffset();
                              }),
                        child: SizedBox(
                          width: frameSize,
                          height: frameSize,
                          child: CustomPaint(
                            painter: _CropPainter(
                              image!,
                              profileCropRect(imageSize, zoom, offset),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.zoom_out),
                        Expanded(
                          child: Slider(
                            value: zoom,
                            min: 1,
                            max: 4,
                            label: '${zoom.toStringAsFixed(1)}×',
                            semanticFormatterCallback: (value) =>
                                '${value.toStringAsFixed(1)} times zoom',
                            onChanged: saving
                                ? null
                                : (value) => setState(() {
                                    offset = offset * (value / zoom);
                                    zoom = value;
                                    constrainOffset();
                                  }),
                          ),
                        ),
                        const Icon(Icons.zoom_in),
                      ],
                    ),
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => setState(() {
                              zoom = 1;
                              offset = Offset.zero;
                            }),
                      child: const Text('Reset'),
                    ),
                  ],
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: image == null || saving ? null : save,
                        child: Text(saving ? 'Preparing photo…' : 'Save photo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawImageRect(
      image,
      source,
      bounds,
      Paint()..filterQuality = FilterQuality.high,
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addOval(bounds);
    canvas.drawPath(mask, Paint()..color = Colors.black54);
    canvas.drawOval(
      bounds.deflate(1),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.source != source || oldDelegate.image != image;
}
