import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/image_overlay.dart';

class CustomImageLayer extends StatelessWidget {
  final ImageOverlayData overlayData;
  final VoidCallback? onTap;
  final bool isEditing;

  const CustomImageLayer({
    super.key,
    required this.overlayData,
    this.onTap,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (overlayData.imageBytes == null) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: ImageOverlayPainter(
        overlayData: overlayData,
        isEditing: isEditing,
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
      ),
    );
  }
}

class ImageOverlayPainter extends CustomPainter {
  final ImageOverlayData overlayData;
  final bool isEditing;
  ui.Image? _image;

  ImageOverlayPainter({
    required this.overlayData,
    required this.isEditing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (overlayData.imageBytes == null) return;

    // Charger l'image de manière synchrone n'est pas possible
    // Cette approche utilise un FutureBuilder dans le widget parent
    // Pour l'instant, on dessine juste un placeholder
    _decodeImage();
  }

  void _decodeImage() async {
    if (overlayData.imageBytes == null) return;
    _image = await decodeImageFromList(overlayData.imageBytes!);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class CustomImageLayerWidget extends StatefulWidget {
  final ImageOverlayData overlayData;
  final VoidCallback? onTap;
  final bool isEditing;

  const CustomImageLayerWidget({
    super.key,
    required this.overlayData,
    this.onTap,
    this.isEditing = false,
  });

  @override
  State<CustomImageLayerWidget> createState() => _CustomImageLayerWidgetState();
}

class _CustomImageLayerWidgetState extends State<CustomImageLayerWidget> {
  ui.Image? _uiImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CustomImageLayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlayData.imageBytes != widget.overlayData.imageBytes) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.overlayData.imageBytes == null) return;
    final codec =
        await ui.instantiateImageCodec(widget.overlayData.imageBytes!);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _uiImage = frame.image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uiImage == null) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: ImageOverlayMapPainter(
        overlayData: widget.overlayData,
        uiImage: _uiImage!,
        isEditing: widget.isEditing,
      ),
      size: Size.infinite,
      child: widget.onTap != null
          ? GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.translucent,
            )
          : null,
    );
  }
}

class ImageOverlayMapPainter extends CustomPainter {
  final ImageOverlayData overlayData;
  final ui.Image uiImage;
  final bool isEditing;

  ImageOverlayMapPainter({
    required this.overlayData,
    required this.uiImage,
    required this.isEditing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    // Calculer la position du centre de l'écran
    final center = Offset(size.width / 2, size.height / 2);

    // Sauvegarder l'état du canvas
    canvas.save();

    // Appliquer la transformation au centre
    canvas.translate(center.dx, center.dy);
    canvas.rotate(overlayData.rotation);
    canvas.scale(overlayData.scale);

    // Dessiner l'image centrée
    final srcRect = Rect.fromLTWH(
        0, 0, uiImage.width.toDouble(), uiImage.height.toDouble());
    final dstRect = Rect.fromLTWH(
      -overlayData.imageWidth / 2,
      -overlayData.imageHeight / 2,
      overlayData.imageWidth,
      overlayData.imageHeight,
    );

    canvas.drawImageRect(uiImage, srcRect, dstRect, paint);

    // Dessiner la bordure en mode édition
    if (isEditing) {
      final borderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / overlayData.scale;

      canvas.drawRect(dstRect, borderPaint);

      // Dessiner les poignées de contrôle
      final handlePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

      final handleRadius = 8.0 / overlayData.scale;

      // Poignées aux coins
      canvas.drawCircle(
          Offset(dstRect.left, dstRect.top), handleRadius, handlePaint);
      canvas.drawCircle(
          Offset(dstRect.right, dstRect.top), handleRadius, handlePaint);
      canvas.drawCircle(
          Offset(dstRect.left, dstRect.bottom), handleRadius, handlePaint);
      canvas.drawCircle(
          Offset(dstRect.right, dstRect.bottom), handleRadius, handlePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ImageOverlayMapPainter oldDelegate) {
    return oldDelegate.overlayData != overlayData ||
        oldDelegate.isEditing != isEditing;
  }
}
