import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/image_overlay.dart';

class ImageOverlayWidget extends StatefulWidget {
  final ImageOverlayData overlayData;
  final bool isEditMode;
  final Function(double dx, double dy)? onMove;

  const ImageOverlayWidget({
    super.key,
    required this.overlayData,
    this.isEditMode = false,
    this.onMove,
  });

  @override
  State<ImageOverlayWidget> createState() => _ImageOverlayWidgetState();
}

class _ImageOverlayWidgetState extends State<ImageOverlayWidget> {
  ui.Image? _uiImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ImageOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlayData.imageBytes != widget.overlayData.imageBytes) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.overlayData.imageBytes == null) return;

    try {
      final codec = await ui.instantiateImageCodec(
        widget.overlayData.imageBytes!,
      );
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _uiImage = frame.image;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uiImage == null) return const SizedBox.shrink();

    return CustomOverlayLayer(
      overlayData: widget.overlayData,
      uiImage: _uiImage!,
      isEditMode: widget.isEditMode,
    );
  }
}

// Widget personnalisé pour afficher l'overlay avec transformation
class CustomOverlayLayer extends StatelessWidget {
  final ImageOverlayData overlayData;
  final ui.Image uiImage;
  final bool isEditMode;

  const CustomOverlayLayer({
    super.key,
    required this.overlayData,
    required this.uiImage,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: OverlayPainter(
            overlayData: overlayData,
            uiImage: uiImage,
            isEditMode: isEditMode,
            camera: MapCamera.of(context),
          ),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

class OverlayPainter extends CustomPainter {
  final ImageOverlayData overlayData;
  final ui.Image uiImage;
  final bool isEditMode;
  final MapCamera camera;

  OverlayPainter({
    required this.overlayData,
    required this.uiImage,
    required this.isEditMode,
    required this.camera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    // Convertir la position géographique en position écran
    final point = camera.latLngToScreenPoint(overlayData.position);
    final centerX = point.x;
    final centerY = point.y;

    canvas.save();

    // Se déplacer au centre de l'image sur la carte
    canvas.translate(centerX, centerY);

    // Appliquer la rotation
    canvas.rotate(overlayData.rotation);

    // Appliquer l'échelle
    canvas.scale(overlayData.scale);

    // Calculer la taille de l'image à afficher (taille visible en pixels)
    // On utilise les dimensions de l'image réelle multipliées par un facteur
    final displayWidth = overlayData.imageWidth * overlayData.scale;
    final displayHeight = overlayData.imageHeight * overlayData.scale;

    // Rectangle source (l'image complète)
    final srcRect = Rect.fromLTWH(
      0,
      0,
      uiImage.width.toDouble(),
      uiImage.height.toDouble(),
    );

    // Rectangle destination (où dessiner sur le canvas)
    // Centré sur la position actuelle
    final dstRect = Rect.fromLTWH(
      -displayWidth / 2 / overlayData.scale,
      -displayHeight / 2 / overlayData.scale,
      displayWidth / overlayData.scale,
      displayHeight / overlayData.scale,
    );

    // Dessiner l'image
    canvas.drawImageRect(uiImage, srcRect, dstRect, paint);

    // Bordure en mode édition
    if (isEditMode) {
      final borderPaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 / overlayData.scale;

      canvas.drawRect(dstRect, borderPaint);

      // Poignées aux coins
      final handlePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

      final handleRadius = 10.0 / overlayData.scale;

      // Coins
      canvas.drawCircle(
        Offset(dstRect.left, dstRect.top),
        handleRadius,
        handlePaint,
      );
      canvas.drawCircle(
        Offset(dstRect.right, dstRect.top),
        handleRadius,
        handlePaint,
      );
      canvas.drawCircle(
        Offset(dstRect.left, dstRect.bottom),
        handleRadius,
        handlePaint,
      );
      canvas.drawCircle(
        Offset(dstRect.right, dstRect.bottom),
        handleRadius,
        handlePaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.overlayData != overlayData ||
        oldDelegate.isEditMode != isEditMode ||
        oldDelegate.camera != camera;
  }
}
