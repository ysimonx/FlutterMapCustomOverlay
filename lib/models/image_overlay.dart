import 'dart:convert';
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';

/// Modèle de données pour un overlay d'image sur la carte.
///
/// Ce modèle stocke toutes les informations nécessaires pour afficher et
/// manipuler une image superposée sur une carte OpenStreetMap.
///
/// Conventions d'unités:
/// - [rotation]: Stockée en DEGRÉS (0-360°)
/// - [referenceMapRotation]: Stockée en RADIANS (même format que MapCamera.rotation)
/// - [position]: Coordonnées géographiques (latitude, longitude)
/// - [scale]: Facteur d'échelle (1.0 = taille normale)
/// - [imageWidth], [imageHeight]: Dimensions d'affichage en pixels logiques
class ImageOverlayData {
  /// Identifiant unique de l'overlay
  final String id;

  /// Position géographique du centre de l'overlay
  final LatLng position;

  /// Facteur d'échelle de l'image (1.0 = taille normale, >1 = plus grand, <1 = plus petit)
  final double scale;

  /// Angle de rotation de l'overlay en DEGRÉS (sens horaire, 0 = nord)
  final double rotation;

  /// Chemin du fichier image
  final String imagePath;

  /// Données binaires de l'image
  final Uint8List? imageBytes;

  /// Largeur d'affichage de l'image en pixels logiques
  final double imageWidth;

  /// Hauteur d'affichage de l'image en pixels logiques
  final double imageHeight;

  /// Indique si l'overlay est verrouillé (suit les mouvements de la carte)
  final bool isLocked;

  /// Niveau de zoom de référence au moment du verrouillage
  final double referenceZoom;

  /// Rotation de la carte de référence en RADIANS au moment du verrouillage
  /// (utilise les mêmes unités que MapCamera.rotation)
  ///
  /// Note: Cette valeur n'est PAS sauvegardée en JSON pour éviter les problèmes
  /// de synchronisation. Elle est capturée uniquement au moment du verrouillage.
  final double referenceMapRotation;

  /// Opacité de l'overlay (0.0 = transparent, 1.0 = opaque)
  final double opacity;

  ImageOverlayData({
    required this.id,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    required this.imagePath,
    this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    this.isLocked = false,
    this.referenceZoom = 13.0,
    this.referenceMapRotation = 0.0,
    this.opacity = 1.0,
  });

  ImageOverlayData copyWith({
    String? id,
    LatLng? position,
    double? scale,
    double? rotation,
    String? imagePath,
    Uint8List? imageBytes,
    double? imageWidth,
    double? imageHeight,
    bool? isLocked,
    double? referenceZoom,
    double? referenceMapRotation,
    double? opacity,
  }) {
    ImageOverlayData x = ImageOverlayData(
      id: id ?? this.id,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      isLocked: isLocked ?? this.isLocked,
      referenceZoom: referenceZoom ?? this.referenceZoom,
      referenceMapRotation: referenceMapRotation ?? this.referenceMapRotation,
      opacity: opacity ?? this.opacity,
    );
    return x;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'scale': scale,
      'rotation': rotation,
      'imagePath': imagePath,
      'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'isLocked': isLocked,
      'referenceZoom': referenceZoom,
      'opacity': opacity,
      // Ne PAS sauvegarder referenceMapRotation - sera capturé au verrouillage
    };
  }

  factory ImageOverlayData.fromJson(Map<String, dynamic> json) {
    return ImageOverlayData(
      id: json['id'],
      position: LatLng(json['latitude'], json['longitude']),
      scale: json['scale'],
      rotation: json['rotation'],
      imagePath: json['imagePath'],
      imageBytes:
          json['imageBytes'] != null ? base64Decode(json['imageBytes']) : null,
      imageWidth: json['imageWidth'],
      imageHeight: json['imageHeight'],
      isLocked: json['isLocked'] ?? false,
      referenceZoom: json['referenceZoom'] ?? 13.0,
      opacity: json['opacity'] ?? 1.0,
      // referenceMapRotation sera toujours 0.0 au chargement
      // et sera mis à jour lors du verrouillage
      referenceMapRotation: 0.0,
    );
  }
}
