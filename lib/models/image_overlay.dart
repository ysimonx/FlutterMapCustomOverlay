import 'dart:convert';
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';

class ImageOverlayData {
  final String id;
  final LatLng position;
  final double scale;
  final double rotation;
  final String imagePath;
  final Uint8List? imageBytes;
  final double imageWidth;
  final double imageHeight;
  final bool isLocked;
  final double referenceZoom; // Niveau de zoom de référence
  final double referenceMapRotation; // Rotation de la carte de référence

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
      // referenceMapRotation sera toujours 0.0 au chargement
      // et sera mis à jour lors du verrouillage
      referenceMapRotation: 0.0,
    );
  }
}
