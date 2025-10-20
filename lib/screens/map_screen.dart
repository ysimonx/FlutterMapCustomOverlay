import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import '../models/image_overlay.dart';
import '../widgets/image_overlay_layer.dart';

/// Écran principal de l'application avec carte interactive et overlay d'image.
///
/// Cette application permet de superposer une image PNG sur une carte OpenStreetMap
/// avec les fonctionnalités suivantes:
/// - Sélection d'image depuis le système de fichiers
/// - Positionnement géographique de l'image
/// - Rotation, zoom et déplacement de l'image
/// - Mode verrouillé: l'image suit les mouvements de la carte
/// - Sauvegarde/chargement de la configuration
///
/// ## Gestion des unités de rotation
///
/// IMPORTANT: Ce projet utilise deux systèmes d'unités pour les rotations:
///
/// 1. **DEGRÉS** (0-360°):
///    - Stockage dans [ImageOverlayData.rotation]
///    - Interface utilisateur (boutons de rotation, affichage)
///    - Méthodes de manipulation: [_rotateImage(deltaDegre)]
///    - Plus intuitif pour l'utilisateur
///
/// 2. **RADIANS** (0-2π):
///    - MapController et MapCamera ([MapCamera.rotation])
///    - Référence de rotation de la carte ([ImageOverlayData.referenceMapRotation])
///    - Canvas.rotate() dans le painter
///    - Standard pour les API de bas niveau
///
/// ### Conversions:
/// - Degrés → Radians: `angle * (pi / 180)`
/// - Radians → Degrés: `angle * (180 / pi)`
///
/// ### Flux de rotation:
/// 1. Utilisateur clique sur bouton de rotation → delta en degrés
/// 2. [_rotateImage()] ajoute le delta (degrés) à [rotation] (degrés)
/// 3. [ImageOverlayPainter] convertit en radians pour canvas.rotate()
/// 4. En mode verrouillé: combine rotation overlay (degrés) + delta carte (radians→degrés)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  ImageOverlayData? _overlay;
  bool _isEditMode = false;
  bool _isLocked = false;
  bool _isInteractingWithOverlay = false;

  LatLng _currentCenter = const LatLng(43.7084, 5.7737); // ITER Cadarache par défaut

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadSavedOverlay();
  }

  Future<void> _getCurrentLocation() async {
    // Si l'overlay est verrouillé, centrer sur l'overlay au lieu de la position GPS
    if (_overlay != null && _isLocked) {
      _centerOnOverlay();
      return;
    }

    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Vérifier si les services de localisation sont activés
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Les services de localisation sont désactivés.');
        return;
      }

      // Vérifier les permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Les permissions de localisation sont refusées.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            'Les permissions de localisation sont refusées définitivement.');
        return;
      }

      // Obtenir la position actuelle
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentCenter = LatLng(position.latitude, position.longitude);
      });

      // Déplacer la carte vers la position actuelle
      _mapController.move(_currentCenter, 13.0);
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la position: $e');
    }
  }

  void _centerOnOverlay() {
    if (_overlay == null) return;

    // Capturer les dimensions de l'écran
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculer la taille cible : l'overlay doit occuper environ 50% de l'écran
    final targetSize =
        (screenWidth < screenHeight ? screenWidth : screenHeight) * 0.5;

    // Taille actuelle de l'overlay en pixels (avec scale et zoom de référence)
    final currentZoom = _mapController.camera.zoom;
    final zoomFactor = currentZoom - _overlay!.referenceZoom;
    final zoomScale = pow(2.0, zoomFactor);
    final currentScale = _overlay!.scale * zoomScale;

    // Dimensions actuelles de l'overlay à l'écran
    final currentWidth = _overlay!.imageWidth * currentScale;
    final currentHeight = _overlay!.imageHeight * currentScale;

    // Calculer le plus grand côté
    final maxCurrentSize =
        currentWidth > currentHeight ? currentWidth : currentHeight;

    // Calculer le zoom nécessaire pour que l'overlay occupe 50% de l'écran
    // ratio = targetSize / maxCurrentSize
    // On doit ajuster le zoom pour atteindre ce ratio
    final ratio = targetSize / maxCurrentSize;

    // Calculer le nouveau zoom
    // ratio = pow(2, newZoomFactor - zoomFactor)
    // log2(ratio) = newZoomFactor - zoomFactor
    final zoomAdjustment = log(ratio) / log(2);
    final newZoom = (currentZoom + zoomAdjustment).clamp(1.0, 18.0);

    // Centrer la carte sur la position de l'overlay
    _mapController.move(_overlay!.position, newZoom);

    setState(() {
      _currentCenter = _overlay!.position;
    });
  }

  Future<void> _loadSavedOverlay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final overlayJson = prefs.getString('image_overlay');

      if (overlayJson != null) {
        final data = jsonDecode(overlayJson);
        setState(() {
          _overlay = ImageOverlayData.fromJson(data);
          _isLocked = _overlay!.isLocked;
          if (_overlay != null) {
            _currentCenter = _overlay!.position;
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement: $e');
    }
  }

  Future<void> _saveOverlay() async {
    if (_overlay == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final overlayJson = jsonEncode(_overlay!.toJson());
      await prefs.setString('image_overlay', overlayJson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Overlay sauvegardé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    // Capturer les dimensions de l'écran avant l'async gap
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final image = img.decodeImage(bytes);

        if (image != null) {
          final center = _mapController.camera.center;

          // Calculer une taille d'affichage appropriée
          // On veut que l'image occupe environ 60% de la largeur de l'écran

          // Taille cible : environ 60% de la plus petite dimension de l'écran
          final targetSize =
              (screenWidth < screenHeight ? screenWidth : screenHeight) * 0.6;

          // Calculer le ratio de l'image
          final imageRatio = image.width / image.height;

          // Calculer la taille d'affichage en conservant le ratio
          double displayWidth;
          double displayHeight;

          if (imageRatio > 1) {
            // Image plus large que haute
            displayWidth = targetSize;
            displayHeight = targetSize / imageRatio;
          } else {
            // Image plus haute que large
            displayHeight = targetSize;
            displayWidth = targetSize * imageRatio;
          }

          setState(() {
            _overlay = ImageOverlayData(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              position: center,
              imagePath: result.files.single.name,
              imageBytes: bytes,
              imageWidth: displayWidth,
              imageHeight: displayHeight,
              scale: 1.0,
              rotation: 0.0,
              isLocked: false,
              referenceZoom: _mapController.camera.zoom,
              referenceMapRotation: _mapController.camera.rotation,
            );
            _isEditMode = true;
            _isLocked = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection: $e')),
        );
      }
    }
  }

  /// Fait pivoter l'overlay d'un angle donné en degrés.
  ///
  /// Cette méthode ajoute [deltaDegre] degrés à la rotation actuelle de l'overlay.
  /// La rotation est désactivée si l'overlay est verrouillé.
  ///
  /// Paramètres:
  /// - [deltaDegre]: Angle de rotation à ajouter en degrés (positif = horaire, négatif = anti-horaire)
  ///
  /// Note: La valeur de rotation est stockée en degrés dans le modèle ImageOverlayData,
  /// et sera convertie en radians lors du rendu dans ImageOverlayPainter.
  void _rotateImage(double deltaDegre) {
    if (_overlay == null || _isLocked) return;
    double? newRotation = _overlay!.rotation + deltaDegre;
    setState(() {
      _overlay = _overlay!.copyWith(
        rotation: (newRotation),
      );
    });
  }

  void _scaleImage(double delta) {
    if (_overlay == null || _isLocked) return;
    setState(() {
      final newScale = (_overlay!.scale + delta).clamp(0.1, 50.0);
      _overlay = _overlay!.copyWith(scale: newScale);
    });
  }

  void _moveImage(double dx, double dy) {
    if (_overlay == null || _isLocked) return;

    final camera = _mapController.camera;

    // Obtenir la position actuelle de l'overlay en coordonnées écran
    final currentScreenPoint = camera.latLngToScreenPoint(_overlay!.position);

    // Ajouter le déplacement en pixels
    final newScreenPoint = Point(
      currentScreenPoint.x + dx,
      currentScreenPoint.y + dy,
    );

    // Convertir la nouvelle position écran en coordonnées géographiques
    final newLatLng = camera.pointToLatLng(newScreenPoint);

    setState(() {
      _overlay = _overlay!.copyWith(position: newLatLng);
    });
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_overlay != null) {
        if (_isLocked) {
          // Quand on verrouille, capturer la rotation actuelle de la carte comme référence
          _overlay = _overlay!.copyWith(
            isLocked: true,
            referenceMapRotation: _mapController.camera.rotation,
          );
          _isEditMode = false;
        } else {
          // Quand on déverrouille, conserver la rotation actuelle
          // Calculer la rotation finale qui était appliquée en mode verrouillé
          final currentMapRotation = _mapController.camera.rotation;
          final mapRotationDelta = currentMapRotation - _overlay!.referenceMapRotation;
          final finalRotation = _overlay!.rotation + mapRotationDelta;

          _overlay = _overlay!.copyWith(
            isLocked: false,
            rotation: finalRotation,
            referenceMapRotation: currentMapRotation,
          );
        }
      }
    });
  }

  void _deleteOverlay() {
    setState(() {
      _overlay = null;
      _isEditMode = false;
      _isLocked = false;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('image_overlay');
    });
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      currentZoom + 1,
    );
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      currentZoom - 1,
    );
  }

  void _rotateMapLeft() {
    final currentRotation = _mapController.camera.rotation;
    const delta = -30;
    final newRotation = currentRotation + delta;

    debugPrint(
        'Rotation LEFT: current=${(currentRotation * 180 / pi).toStringAsFixed(1)}°, new=${(newRotation * 180 / pi).toStringAsFixed(1)}°');

    // Utiliser moveAndRotate() pour un contrôle complet
    _mapController.moveAndRotate(
      _mapController.camera.center,
      _mapController.camera.zoom,
      newRotation,
    );

    // Forcer un setState pour que le StreamBuilder se mette à jour
    setState(() {});
  }

  void _rotateMapRight() {
    final currentRotation = _mapController.camera.rotation;
    const delta = 30;
    final newRotation = currentRotation + delta;

    debugPrint(
        'Rotation RIGHT: current=${(currentRotation * 180 / pi).toStringAsFixed(1)}°, new=${(newRotation * 180 / pi).toStringAsFixed(1)}°');

    // Utiliser moveAndRotate() pour un contrôle complet
    _mapController.moveAndRotate(
      _mapController.camera.center,
      _mapController.camera.zoom,
      newRotation,
    );

    // Forcer un setState pour que le StreamBuilder se mette à jour
    setState(() {});
  }

  void _resetMapRotation() {
    debugPrint('RESET rotation to 0°');

    _mapController.moveAndRotate(
      _mapController.camera.center,
      _mapController.camera.zoom,
      0.0,
    );

    // Forcer un setState pour que le StreamBuilder se mette à jour
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte avec Overlay'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_overlay != null && !_isLocked)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Sauvegarder',
              onPressed: _saveOverlay,
            ),
          if (_overlay != null)
            IconButton(
              icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
              tooltip: _isLocked ? 'Déverrouiller' : 'Verrouiller',
              onPressed: _toggleLock,
            ),
          if (_overlay != null)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Supprimer',
              onPressed: _deleteOverlay,
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 13.0,
              initialRotation: 0.0,
              interactionOptions: InteractionOptions(
                flags: _isInteractingWithOverlay
                    ? InteractiveFlag.none
                    : (_isLocked
                        ? InteractiveFlag.all
                        : InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_map_overlay',
              ),
              if (_overlay != null)
                // Envelopper dans un StreamBuilder pour forcer le rebuild sur les changements de carte
                StreamBuilder<MapEvent>(
                  stream: _mapController.mapEventStream,
                  builder: (context, snapshot) {
                    return ImageOverlayLayer(
                      overlayData: _overlay!,
                      isEditMode: _isEditMode && !_isLocked,
                      onPositionChanged: (newPosition) {
                        setState(() {
                          _overlay = _overlay!.copyWith(position: newPosition);
                        });
                      },
                      onRotationChanged: (newRotation) {
                        setState(() {
                          _overlay = _overlay!.copyWith(rotation: newRotation);
                        });
                      },
                      onInteractionChanged: (isInteracting) {
                        setState(() {
                          _isInteractingWithOverlay = isInteracting;
                        });
                      },
                    );
                  },
                ),
            ],
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: _zoomIn,
                  tooltip: 'Zoom avant',
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: _zoomOut,
                  tooltip: 'Zoom arrière',
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'my_location',
                  mini: true,
                  onPressed: _getCurrentLocation,
                  tooltip: (_overlay != null && _isLocked)
                      ? 'Centrer sur l\'overlay'
                      : 'Ma position',
                  child: Icon(
                    (_overlay != null && _isLocked)
                        ? Icons.center_focus_strong
                        : Icons.my_location,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Column(
              children: [
                // Affichage de l'angle de rotation actuel
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: StreamBuilder<MapEvent>(
                    stream: _mapController.mapEventStream,
                    builder: (context, snapshot) {
                      final rotation = _mapController.camera.rotation;
                      final degrees = rotation.toStringAsFixed(1);
                      return Text(
                        '$degrees°',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'rotate_left',
                  mini: true,
                  onPressed: _rotateMapLeft,
                  tooltip: 'Rotation gauche',
                  child: const Icon(Icons.rotate_left),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'rotate_right',
                  mini: true,
                  onPressed: _rotateMapRight,
                  tooltip: 'Rotation droite',
                  child: const Icon(Icons.rotate_right),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'reset_rotation',
                  mini: true,
                  onPressed: _resetMapRotation,
                  tooltip: 'Réinitialiser rotation',
                  child: const Icon(Icons.compass_calibration),
                ),
              ],
            ),
          ),
          if (_overlay != null && _isEditMode && !_isLocked)
            Positioned(
              bottom: 20,
              left: 80,
              right: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Première ligne: Rotation, Échelle, Déplacement
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Rotation
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.rotate_left, size: 20),
                                iconSize: 20,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () => _rotateImage(-1),
                                tooltip: 'Rotation gauche',
                              ),
                              IconButton(
                                icon: const Icon(Icons.rotate_right, size: 20),
                                iconSize: 20,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () => _rotateImage(1),
                                tooltip: 'Rotation droite',
                              ),
                            ],
                          ),
                          // Échelle
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.zoom_out, size: 20),
                                iconSize: 20,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () => _scaleImage(-0.05),
                                tooltip: 'Réduire',
                              ),
                              IconButton(
                                icon: const Icon(Icons.zoom_in, size: 20),
                                iconSize: 20,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () => _scaleImage(0.05),
                                tooltip: 'Agrandir',
                              ),
                            ],
                          ),
                          // Déplacement compact
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_upward, size: 16),
                                iconSize: 16,
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(),
                                onPressed: () => _moveImage(0, -10),
                                tooltip: 'Haut',
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, size: 16),
                                    iconSize: 16,
                                    padding: const EdgeInsets.all(2),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _moveImage(-10, 0),
                                    tooltip: 'Gauche',
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward, size: 16),
                                    iconSize: 16,
                                    padding: const EdgeInsets.all(2),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _moveImage(10, 0),
                                    tooltip: 'Droite',
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward, size: 16),
                                iconSize: 16,
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(),
                                onPressed: () => _moveImage(0, 10),
                                tooltip: 'Bas',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Deuxième ligne: Transparence (compacte)
                      Row(
                        children: [
                          const Icon(Icons.opacity, size: 16),
                          Expanded(
                            child: Slider(
                              value: _overlay!.opacity,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              onChanged: (value) {
                                setState(() {
                                  _overlay = _overlay!.copyWith(opacity: value);
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 35,
                            child: Text(
                              '${(_overlay!.opacity * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _overlay == null
          ? FloatingActionButton.extended(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Ajouter une image'),
            )
          : !_isLocked && !_isEditMode
              ? FloatingActionButton.extended(
                  onPressed: () {
                    setState(() {
                      _isEditMode = true;
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Éditer'),
                )
              : _isEditMode
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        setState(() {
                          _isEditMode = false;
                        });
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Terminer'),
                    )
                  : null,
    );
  }
}
