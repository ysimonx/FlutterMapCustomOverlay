import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/image_overlay.dart';

/// Layer personnalisé pour afficher une image overlay sur la carte
class ImageOverlayLayer extends StatefulWidget {
  final ImageOverlayData overlayData;
  final bool isEditMode;

  const ImageOverlayLayer({
    super.key,
    required this.overlayData,
    this.isEditMode = false,
  });

  @override
  State<ImageOverlayLayer> createState() => _ImageOverlayLayerState();
}

class _ImageOverlayLayerState extends State<ImageOverlayLayer> {
  ui.Image? _uiImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ImageOverlayLayer oldWidget) {
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
    if (_uiImage == null) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: ImageOverlayPainter(
        overlayData: widget.overlayData,
        uiImage: _uiImage!,
        isEditMode: widget.isEditMode,
        camera: MapCamera.of(context),
      ),
      size: Size.infinite,
    );
  }
}

class ImageOverlayPainter extends CustomPainter {
  final ImageOverlayData overlayData;
  final ui.Image uiImage;
  final bool isEditMode;
  final MapCamera camera;

  ImageOverlayPainter({
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

    // Si l'overlay est verrouillé, il suit la rotation de la carte
    // Sinon, il garde sa rotation propre
    final currentMapRotation = camera.rotation;

    // Debug : afficher la rotation de la carte
    // print('Camera rotation: $currentMapRotation, isLocked: ${overlayData.isLocked}, ref: ${overlayData.referenceMapRotation}');

    double finalRotation;
    if (overlayData.isLocked) {
      // Mode verrouillé : l'overlay suit la rotation de la carte
      // rotation finale = rotation overlay + (rotation carte actuelle - rotation carte de référence)
      final mapRotationDelta =
          currentMapRotation - overlayData.referenceMapRotation;
      finalRotation = overlayData.rotation + mapRotationDelta;
      // print('Locked mode - finalRotation: $finalRotation (overlay: ${overlayData.rotation}, delta: $mapRotationDelta)');
    } else {
      // Mode édition : l'overlay garde sa rotation indépendante
      finalRotation = overlayData.rotation;
    }

    canvas.rotate(finalRotation * (pi / 180));

    // Calculer le facteur de zoom pour que l'overlay suive le zoom de la carte
    final currentZoom = camera.zoom;
    final zoomFactor = currentZoom - overlayData.referenceZoom;
    final zoomScale = pow(2.0, zoomFactor);

    // Appliquer l'échelle combinée (échelle utilisateur * facteur de zoom)
    final finalScale = overlayData.scale * zoomScale;
    canvas.scale(finalScale);

    // Dimensions de l'image à afficher
    final displayWidth = overlayData.imageWidth;
    final displayHeight = overlayData.imageHeight;

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
      -displayWidth / 2,
      -displayHeight / 2,
      displayWidth,
      displayHeight,
    );

    // Dessiner l'image
    canvas.drawImageRect(uiImage, srcRect, dstRect, paint);

    // Bordure en mode édition
    if (isEditMode) {
      final borderPaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawRect(dstRect, borderPaint);

      // Poignées aux coins
      final handlePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

      final handleRadius = 10.0;

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

      // Poignées au milieu des côtés
      final middleHandlePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset((dstRect.left + dstRect.right) / 2, dstRect.top),
        handleRadius * 0.7,
        middleHandlePaint,
      );
      canvas.drawCircle(
        Offset((dstRect.left + dstRect.right) / 2, dstRect.bottom),
        handleRadius * 0.7,
        middleHandlePaint,
      );
      canvas.drawCircle(
        Offset(dstRect.left, (dstRect.top + dstRect.bottom) / 2),
        handleRadius * 0.7,
        middleHandlePaint,
      );
      canvas.drawCircle(
        Offset(dstRect.right, (dstRect.top + dstRect.bottom) / 2),
        handleRadius * 0.7,
        middleHandlePaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ImageOverlayPainter oldDelegate) {
    return oldDelegate.overlayData != overlayData ||
        oldDelegate.isEditMode != isEditMode ||
        oldDelegate.camera != camera;
  }
}
