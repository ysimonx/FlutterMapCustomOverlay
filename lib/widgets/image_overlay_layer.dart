import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/image_overlay.dart';

/// Widget personnalisé pour afficher une image overlay sur une carte flutter_map.
///
/// Ce widget crée un layer qui affiche une image positionnée géographiquement
/// sur la carte, avec support pour la rotation, le zoom et le verrouillage.
///
/// Fonctionnalités:
/// - Positionnement géographique précis via des coordonnées LatLng
/// - Rotation de l'image (stockée en degrés, appliquée en radians)
/// - Zoom adaptatif qui suit le niveau de zoom de la carte
/// - Mode verrouillé: l'overlay suit les rotations de la carte
/// - Mode édition: affiche des poignées visuelles pour la manipulation
/// - Glisser-déposer pour déplacer l'overlay en mode édition
///
/// Gestion des unités de rotation:
/// - Les angles sont stockés en DEGRÉS dans [ImageOverlayData.rotation]
/// - La carte utilise des RADIANS ([MapCamera.rotation])
/// - La conversion degrés → radians est effectuée dans [ImageOverlayPainter]
class ImageOverlayLayer extends StatefulWidget {
  /// Données de configuration de l'overlay (position, rotation, échelle, etc.)
  final ImageOverlayData overlayData;

  /// Active l'affichage des poignées de manipulation (bordures et coins)
  final bool isEditMode;

  /// Callback appelé quand l'overlay est déplacé par glisser-déposer
  final Function(LatLng newPosition)? onPositionChanged;

  /// Callback appelé quand l'overlay est pivoté via la poignée de rotation
  final Function(double newRotation)? onRotationChanged;

  /// Callback appelé quand l'overlay est redimensionné via un coin
  final Function(double newScale)? onScaleChanged;

  /// Callback appelé pour indiquer qu'une interaction est en cours (pour désactiver la carte)
  final Function(bool isInteracting)? onInteractionChanged;

  const ImageOverlayLayer({
    super.key,
    required this.overlayData,
    this.isEditMode = false,
    this.onPositionChanged,
    this.onRotationChanged,
    this.onScaleChanged,
    this.onInteractionChanged,
  });

  @override
  State<ImageOverlayLayer> createState() => _ImageOverlayLayerState();
}

class _ImageOverlayLayerState extends State<ImageOverlayLayer> {
  ui.Image? _uiImage;
  Offset? _dragStartPosition;
  LatLng? _overlayStartPosition;
  bool _isRotating = false;
  bool _isScaling = false;
  double? _initialRotation;
  double? _initialAngle;
  double? _initialScale;
  double? _initialDistance;

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

  /// Vérifie si le point touché est sur la poignée de rotation
  bool _isPointOnRotationHandle(Offset localPoint, Offset rotationHandleCenter, double scale) {
    const handleRadius = 10.0;
    const rotationHandleSize = handleRadius * 1.2;

    // Distance entre le point touché et le centre de la poignée de rotation
    final distance = (localPoint - rotationHandleCenter).distance;

    // Prendre en compte l'échelle pour le rayon de détection
    return distance <= (rotationHandleSize * scale * 1.5); // Zone de détection plus large
  }

  /// Vérifie si le point touché est sur un des coins de l'image
  /// Retourne l'offset du coin touché ou null
  Offset? _getCornerIfTouched(Offset localPoint, Rect dstRect, double finalScale) {
    const handleRadius = 10.0;
    const detectionRadius = handleRadius * 1.5;

    final corners = [
      Offset(dstRect.left, dstRect.top), // Coin haut-gauche
      Offset(dstRect.right, dstRect.top), // Coin haut-droit
      Offset(dstRect.left, dstRect.bottom), // Coin bas-gauche
      Offset(dstRect.right, dstRect.bottom), // Coin bas-droit
    ];

    for (final corner in corners) {
      final distance = (localPoint - corner).distance;
      if (distance <= detectionRadius) {
        return corner;
      }
    }

    return null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.isEditMode) return;

    final camera = MapCamera.of(context);

    // Convertir la position de l'overlay en coordonnées écran
    final centerPoint = camera.latLngToScreenPoint(widget.overlayData.position);

    // Calculer la position de la poignée de rotation en coordonnées écran
    final currentZoom = camera.zoom;
    final zoomFactor = currentZoom - widget.overlayData.referenceZoom;
    final zoomScale = pow(2.0, zoomFactor).toDouble();
    final finalScale = widget.overlayData.scale * zoomScale;

    const rotationHandleDistance = 40.0;
    final displayWidth = widget.overlayData.imageWidth;
    final displayHeight = widget.overlayData.imageHeight;

    // Rectangle de l'image en coordonnées locales (avant rotation et échelle)
    final dstRect = Rect.fromLTWH(
      -displayWidth / 2,
      -displayHeight / 2,
      displayWidth,
      displayHeight,
    );

    // Calculer la position du point touché dans le système de coordonnées de l'image
    // (centré sur l'overlay, avant rotation et échelle)
    final dx = event.localPosition.dx - centerPoint.x;
    final dy = event.localPosition.dy - centerPoint.y;

    // Inverser l'échelle
    final localX = dx / finalScale;
    final localY = dy / finalScale;

    // Inverser la rotation
    final rotationRad = widget.overlayData.rotation * (pi / 180);
    final cosTheta = cos(-rotationRad);
    final sinTheta = sin(-rotationRad);

    final unrotatedX = localX * cosTheta - localY * sinTheta;
    final unrotatedY = localX * sinTheta + localY * cosTheta;

    final localPoint = Offset(unrotatedX, unrotatedY);

    // Vérifier si on touche un coin (priorité 1)
    final touchedCorner = _getCornerIfTouched(localPoint, dstRect, finalScale);
    if (touchedCorner != null) {
      setState(() {
        _isScaling = true;
        _isRotating = false;
        _initialScale = widget.overlayData.scale;

        // Calculer la distance initiale entre le centre et le coin touché
        _initialDistance = touchedCorner.distance;
      });
      // Notifier qu'une interaction a commencé
      widget.onInteractionChanged?.call(true);
      return;
    }

    // Position de la poignée de rotation en coordonnées locales (avant rotation)
    final localRotationHandleOffset = Offset(0, -displayHeight / 2 - rotationHandleDistance);

    // Appliquer la rotation à la poignée
    final rotatedHandleX = localRotationHandleOffset.dx * cos(rotationRad) - localRotationHandleOffset.dy * sin(rotationRad);
    final rotatedHandleY = localRotationHandleOffset.dx * sin(rotationRad) + localRotationHandleOffset.dy * cos(rotationRad);

    // Appliquer l'échelle
    final scaledOffset = Offset(rotatedHandleX * finalScale, rotatedHandleY * finalScale);

    // Position finale de la poignée en coordonnées écran
    final rotationHandleScreen = Offset(
      centerPoint.x + scaledOffset.dx,
      centerPoint.y + scaledOffset.dy,
    );

    // Vérifier si on touche la poignée de rotation (priorité 2)
    if (_isPointOnRotationHandle(event.localPosition, rotationHandleScreen, finalScale)) {
      setState(() {
        _isRotating = true;
        _isScaling = false;
        _initialRotation = widget.overlayData.rotation;

        // Calculer l'angle initial entre le centre et le point touché
        _initialAngle = atan2(dy, dx) * 180 / pi;
      });
      // Notifier qu'une interaction a commencé
      widget.onInteractionChanged?.call(true);
    } else {
      // Mode déplacement (priorité 3)
      setState(() {
        _isRotating = false;
        _isScaling = false;
        _dragStartPosition = event.localPosition;
        _overlayStartPosition = widget.overlayData.position;
      });
      // Notifier qu'une interaction a commencé
      widget.onInteractionChanged?.call(true);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.isEditMode) return;

    final camera = MapCamera.of(context);

    if (_isScaling) {
      // Mode redimensionnement
      final centerPoint = camera.latLngToScreenPoint(widget.overlayData.position);

      // Calculer la distance actuelle entre le centre et le point touché
      final dx = event.localPosition.dx - centerPoint.x;
      final dy = event.localPosition.dy - centerPoint.y;
      final currentDistance = sqrt(dx * dx + dy * dy);

      // Calculer le ratio de changement
      final scaleRatio = currentDistance / _initialDistance!;

      // Nouvelle échelle
      final newScale = (_initialScale! * scaleRatio).clamp(0.1, 50.0);

      // Notifier le parent du changement d'échelle
      widget.onScaleChanged?.call(newScale);
    } else if (_isRotating) {
      // Mode rotation
      final centerPoint = camera.latLngToScreenPoint(widget.overlayData.position);

      // Calculer l'angle actuel entre le centre et le point touché
      final dx = event.localPosition.dx - centerPoint.x;
      final dy = event.localPosition.dy - centerPoint.y;
      final currentAngle = atan2(dy, dx) * 180 / pi;

      // Calculer la différence d'angle
      final angleDelta = currentAngle - _initialAngle!;

      // Nouvelle rotation
      final newRotation = _initialRotation! + angleDelta;

      // Notifier le parent du changement de rotation
      widget.onRotationChanged?.call(newRotation);
    } else {
      // Mode déplacement
      if (_dragStartPosition == null || _overlayStartPosition == null) return;

      // Calculer le déplacement en pixels
      final delta = event.localPosition - _dragStartPosition!;

      // Convertir la position de départ de l'overlay en coordonnées écran
      final startScreenPoint = camera.latLngToScreenPoint(_overlayStartPosition!);

      // Ajouter le déplacement
      final newScreenPoint = Point(
        startScreenPoint.x + delta.dx,
        startScreenPoint.y + delta.dy,
      );

      // Convertir la nouvelle position écran en coordonnées géographiques
      final newLatLng = camera.pointToLatLng(newScreenPoint);

      // Notifier le parent du changement de position
      widget.onPositionChanged?.call(newLatLng);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    setState(() {
      _isRotating = false;
      _isScaling = false;
      _dragStartPosition = null;
      _overlayStartPosition = null;
      _initialRotation = null;
      _initialAngle = null;
      _initialScale = null;
      _initialDistance = null;
    });
    // Notifier que l'interaction est terminée
    widget.onInteractionChanged?.call(false);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    setState(() {
      _isRotating = false;
      _isScaling = false;
      _dragStartPosition = null;
      _overlayStartPosition = null;
      _initialRotation = null;
      _initialAngle = null;
      _initialScale = null;
      _initialDistance = null;
    });
    // Notifier que l'interaction est terminée
    widget.onInteractionChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    if (_uiImage == null) {
      return const SizedBox.shrink();
    }

    final customPaint = CustomPaint(
      painter: ImageOverlayPainter(
        overlayData: widget.overlayData,
        uiImage: _uiImage!,
        isEditMode: widget.isEditMode,
        camera: MapCamera.of(context),
      ),
      size: Size.infinite,
    );

    // En mode édition, envelopper dans un Listener pour capturer les événements pointer
    if (widget.isEditMode) {
      return Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        behavior: HitTestBehavior.translucent,
        child: customPaint,
      );
    }

    return customPaint;
  }
}

/// Painter personnalisé pour dessiner l'overlay d'image sur le canvas.
///
/// Ce painter gère toute la logique de rendu de l'image overlay, incluant:
/// - Conversion des coordonnées géographiques en coordonnées écran
/// - Application de la rotation (conversion degrés → radians)
/// - Application du zoom adaptatif
/// - Gestion du mode verrouillé (l'overlay suit la rotation de la carte)
/// - Affichage des poignées de manipulation en mode édition
///
/// Transformations appliquées dans l'ordre:
/// 1. Translate au centre de l'overlay (coordonnées écran)
/// 2. Rotate (angle en radians converti depuis les degrés)
/// 3. Scale (facteur d'échelle * facteur de zoom)
/// 4. Draw image (centrée sur l'origine transformée)
class ImageOverlayPainter extends CustomPainter {
  /// Données de configuration de l'overlay
  final ImageOverlayData overlayData;

  /// Image décodée prête pour le rendu
  final ui.Image uiImage;

  /// Mode édition (affiche les poignées de manipulation)
  final bool isEditMode;

  /// Caméra de la carte pour les conversions de coordonnées
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
      ..isAntiAlias = true
      ..color = Color.fromRGBO(255, 255, 255, overlayData.opacity);

    // Convertir la position géographique en position écran
    final point = camera.latLngToScreenPoint(overlayData.position);
    final centerX = point.x;
    final centerY = point.y;

    canvas.save();

    // Se déplacer au centre de l'image sur la carte
    canvas.translate(centerX, centerY);

    // Gestion de la rotation de l'overlay
    // Note: Les rotations sont stockées en DEGRÉS dans le modèle ImageOverlayData,
    // mais la MapCamera utilise des RADIANS, et canvas.rotate() attend également des RADIANS.

    // Récupérer la rotation actuelle de la carte (en radians)
    final currentMapRotation = camera.rotation;

    // Calculer la rotation finale de l'overlay en degrés
    double finalRotationDegrees;
    if (overlayData.isLocked) {
      // Mode verrouillé : l'overlay suit la rotation de la carte
      // 1. currentMapRotation est en degrés
      final currentMapRotationDegrees = currentMapRotation;
      final referenceMapRotationDegrees = overlayData.referenceMapRotation;

      // 2. Calculer le delta de rotation de la carte (en degrés)
      final mapRotationDeltaDegrees =
          currentMapRotationDegrees - referenceMapRotationDegrees;

      // 3. Rotation finale = rotation de l'overlay + delta de rotation de la carte
      finalRotationDegrees = overlayData.rotation + mapRotationDeltaDegrees;
    } else {
      // Mode édition : l'overlay garde sa rotation indépendante (en degrés)
      finalRotationDegrees = overlayData.rotation;
    }

    // Convertir la rotation finale en radians pour canvas.rotate()
    canvas.rotate(finalRotationDegrees * (pi / 180));

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

      const handleRadius = 10.0;

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

      // Poignée de rotation (au-dessus du centre haut)
      const rotationHandleDistance = 40.0; // Distance depuis le bord supérieur
      final rotationHandleCenter = Offset(
        (dstRect.left + dstRect.right) / 2,
        dstRect.top - rotationHandleDistance,
      );

      // Ligne connectant la poignée de rotation au bord supérieur
      final linePaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset((dstRect.left + dstRect.right) / 2, dstRect.top),
        rotationHandleCenter,
        linePaint,
      );

      // Cercle de la poignée de rotation
      final rotationHandlePaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        rotationHandleCenter,
        handleRadius * 1.2,
        rotationHandlePaint,
      );

      // Bordure de la poignée de rotation
      final rotationHandleBorderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(
        rotationHandleCenter,
        handleRadius * 1.2,
        rotationHandleBorderPaint,
      );

      // Afficher les coordonnées géographiques aux 4 coins
      _drawCornerCoordinates(canvas, dstRect, finalRotationDegrees, finalScale);
    }

    canvas.restore();
  }

  /// Dessine les coordonnées géographiques (lat/long) aux 4 coins de l'overlay
  void _drawCornerCoordinates(
      Canvas canvas, Rect dstRect, double rotationDegrees, double scale) {
    // Les 4 coins dans le système de coordonnées local de l'image (avant rotation)
    final corners = [
      Offset(dstRect.left, dstRect.top), // Coin haut-gauche
      Offset(dstRect.right, dstRect.top), // Coin haut-droit
      Offset(dstRect.left, dstRect.bottom), // Coin bas-gauche
      Offset(dstRect.right, dstRect.bottom), // Coin bas-droit
    ];

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Sauvegarder l'état actuel (avec les transformations appliquées)
    canvas.save();

    // Annuler la rotation et l'échelle pour revenir aux coordonnées écran
    canvas.scale(1 / scale);
    canvas.rotate(-rotationDegrees * (pi / 180));

    for (int i = 0; i < corners.length; i++) {
      final corner = corners[i];

      // Appliquer les transformations pour obtenir la position écran réelle
      // 1. Appliquer l'échelle
      final scaledCorner = Offset(corner.dx * scale, corner.dy * scale);

      // 2. Appliquer la rotation
      final rotationRad = rotationDegrees * (pi / 180);
      final cosTheta = cos(rotationRad);
      final sinTheta = sin(rotationRad);

      final rotatedX = scaledCorner.dx * cosTheta - scaledCorner.dy * sinTheta;
      final rotatedY = scaledCorner.dx * sinTheta + scaledCorner.dy * cosTheta;

      // 3. Ajouter le centre de l'image (coordonnées écran)
      final centerPoint = camera.latLngToScreenPoint(overlayData.position);
      final screenX = centerPoint.x + rotatedX;
      final screenY = centerPoint.y + rotatedY;

      // Convertir les coordonnées écran en coordonnées géographiques
      final point = Point(screenX, screenY);
      final latLng = camera.pointToLatLng(point);

      // Formater le texte
      final text =
          '${latLng.latitude.toStringAsFixed(6)}\n${latLng.longitude.toStringAsFixed(6)}';

      textPainter.text = TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black87,
          shadows: [
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 2,
              color: Colors.black,
            ),
          ],
        ),
      );

      textPainter.layout();

      // Positionner le texte en fonction du coin
      double offsetX;
      double offsetY;

      // Calculer les coordonnées pour le texte dans le système transformé
      canvas.save();
      canvas.rotate(rotationDegrees * (pi / 180));
      canvas.scale(scale);

      switch (i) {
        case 0: // Haut-gauche
          offsetX = corner.dx - textPainter.width - 5;
          offsetY = corner.dy - textPainter.height - 5;
          break;
        case 1: // Haut-droit
          offsetX = corner.dx + 5;
          offsetY = corner.dy - textPainter.height - 5;
          break;
        case 2: // Bas-gauche
          offsetX = corner.dx - textPainter.width - 5;
          offsetY = corner.dy + 5;
          break;
        case 3: // Bas-droit
          offsetX = corner.dx + 5;
          offsetY = corner.dy + 5;
          break;
        default:
          offsetX = 0;
          offsetY = 0;
      }

      textPainter.paint(canvas, Offset(offsetX, offsetY));
      canvas.restore();
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
