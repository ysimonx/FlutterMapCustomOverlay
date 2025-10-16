# Flutter Map Custom Overlay

Application Flutter multiplateforme (Web, Android, iOS) permettant d'ajouter des overlays d'images personnalisées sur une carte OpenStreetMap.

## Fonctionnalités

- Navigation sur une carte OpenStreetMap interactive
- **Géolocalisation automatique** : La carte se centre automatiquement sur votre position actuelle au démarrage
- **Contrôles de carte** :
  - Boutons de zoom avant/arrière
  - Bouton pour recentrer sur votre position actuelle
- Ajout d'images PNG en overlay sur la carte
- Manipulation de l'overlay :
  - Déplacement
  - Rotation
  - Redimensionnement (zoom)
- Conservation des proportions de l'image d'origine
- Sauvegarde de la configuration de l'overlay
- Verrouillage de l'overlay pour navigation normale de la carte
- Compatible Web, Android et iOS

## Installation

### Prérequis

- Flutter SDK (>=3.0.0)
- Un IDE (VS Code, Android Studio, ou IntelliJ)
- Pour Android : Android Studio avec SDK
- Pour iOS : Xcode (Mac uniquement)

### Étapes d'installation

1. Cloner ou télécharger ce projet

2. Installer les dépendances :
```bash
flutter pub get
```

3. Lancer l'application :

**Pour Web :**
```bash
flutter run -d chrome
```

**Pour Android :**
```bash
flutter run -d android
```

**Pour iOS :**
```bash
flutter run -d ios
```

## Utilisation

### 1. Navigation sur la carte

Au démarrage, l'application demande l'autorisation d'accès à votre position et centre automatiquement la carte sur votre emplacement actuel.

**Boutons de contrôle de la carte** (en haut à droite) :
- **+** : Zoom avant sur la carte
- **-** : Zoom arrière sur la carte
- **📍** : Recentrer la carte sur votre position actuelle

### 2. Ajouter une image

1. Cliquez sur le bouton "Ajouter une image" (flottant en bas à droite)
2. Sélectionnez un fichier PNG depuis votre appareil
3. L'image apparaît au centre de la carte actuelle

### 3. Éditer l'overlay

Une fois l'image ajoutée, le mode édition s'active automatiquement avec un panneau de contrôle :

- **Rotation** : Utilisez les boutons avec flèches circulaires
- **Échelle** : Utilisez les boutons zoom + et -
- **Déplacement** : Utilisez les flèches directionnelles

L'overlay est entouré d'une bordure bleue avec des poignées aux coins en mode édition.

### 4. Sauvegarder

Cliquez sur l'icône de sauvegarde dans la barre d'application pour enregistrer la configuration actuelle de l'overlay.

### 5. Verrouiller

Cliquez sur l'icône de cadenas pour verrouiller l'overlay :
- En mode verrouillé, l'overlay reste fixe sur la carte
- Vous pouvez naviguer normalement sur la carte
- L'overlay se déplace avec la carte

### 6. Supprimer

Cliquez sur l'icône de suppression pour retirer l'overlay de la carte.

## Architecture du projet

```
lib/
├── main.dart                          # Point d'entrée de l'application
├── models/
│   └── image_overlay.dart             # Modèle de données pour l'overlay
├── screens/
│   └── map_screen.dart                # Écran principal avec la carte
└── widgets/
    └── image_overlay_layer.dart       # Widget de rendu de l'overlay
```

### Composants principaux

#### `ImageOverlayData` (models/image_overlay.dart)
Modèle de données stockant la configuration de l'overlay:
- Position géographique (LatLng)
- **Rotation en DEGRÉS** (0-360°)
- Échelle et dimensions d'affichage
- État de verrouillage
- **Rotation de référence de la carte en RADIANS** (pour le mode verrouillé)

#### `MapScreen` (screens/map_screen.dart)
Écran principal gérant:
- Contrôle de la carte flutter_map
- Interactions utilisateur (boutons de rotation, zoom, déplacement)
- Gestion des modes (édition, verrouillé)
- Sauvegarde/chargement de la configuration
- Géolocalisation GPS

#### `ImageOverlayLayer` (widgets/image_overlay_layer.dart)
Widget de rendu CustomPaint gérant:
- Conversion coordonnées géographiques ↔ écran
- Application des transformations (rotation, zoom, translation)
- Rendu avec Canvas API
- Mode édition avec poignées visuelles

## Dépendances principales

- **flutter_map** : Affichage de cartes OpenStreetMap
- **latlong2** : Gestion des coordonnées géographiques
- **geolocator** : Géolocalisation de l'utilisateur
- **file_picker** : Sélection de fichiers
- **image** : Traitement d'images
- **shared_preferences** : Persistance locale des données

## Notes techniques

### Gestion des rotations

⚠️ **IMPORTANT**: Ce projet utilise **deux systèmes d'unités** pour les rotations.

#### 1. DEGRÉS (0-360°)
**Utilisé pour:**
- Stockage dans `ImageOverlayData.rotation`
- Interface utilisateur (boutons ±15°, affichage)
- Paramètre de la méthode `_rotateImage(double deltaDegre)`

**Raison:** Plus intuitif pour l'utilisateur (30° est plus parlant que 0.524 radians)

#### 2. RADIANS (0-2π)
**Utilisé pour:**
- `MapCamera.rotation` (flutter_map utilise toujours des radians)
- `ImageOverlayData.referenceMapRotation` (référence pour le mode verrouillé)
- `Canvas.rotate()` (API de dessin Flutter standard)

**Raison:** Standard pour les APIs de bas niveau et les calculs mathématiques

### Conversions

```dart
// Degrés → Radians
double radians = degrees * (pi / 180);

// Radians → Degrés
double degrees = radians * (180 / pi);
```

### Flux de rotation de l'overlay

1. **Utilisateur clique sur bouton de rotation (±15°)**
   ```dart
   _rotateImage(15.0); // Delta en degrés
   ```

2. **Mise à jour du modèle (en degrés)**
   ```dart
   rotation = currentRotation + deltaDegre; // Stocké en degrés
   ```

3. **Rendu dans ImageOverlayPainter (conversion en radians)**
   ```dart
   canvas.rotate(finalRotationDegrees * (pi / 180)); // Conversion pour Canvas
   ```

4. **En mode verrouillé: synchronisation avec la carte**
   ```dart
   // La carte rotate en degres
   double mapDeltaDegrees =
       (currentMapRotation - referenceMapRotation) ;

   // Combiné avec la rotation de l'overlay (en degrés)
   finalRotation = overlayRotation + mapDeltaDegrees;
   ```

### Rotation de la carte

Les boutons de rotation de la carte (en bas à gauche) utilisent ±30°:
```dart
void _rotateMapLeft() {
  final currentRotation = mapController.camera.rotation; // en radians
  const delta = -30.0; // en degrés
  final newRotation = currentRotation + delta;
  mapController.moveAndRotate(center, zoom, newRotation);
}
```

Un indicateur d'angle en temps réel affiche la rotation actuelle de la carte en degrés.

### Points d'attention

#### ⚠️ Persistance de `referenceMapRotation`

`referenceMapRotation` n'est **PAS sauvegardée** en JSON car:
- Elle doit être capturée uniquement au moment du verrouillage
- La sauvegarder causerait des problèmes de synchronisation
- Elle est toujours réinitialisée à `0.0` au chargement

```dart
// toJson() - NE PAS inclure referenceMapRotation
Map<String, dynamic> toJson() {
  return {
    'rotation': rotation, // en degrés ✓
    'referenceZoom': referenceZoom,
    // referenceMapRotation omis volontairement ✓
  };
}
```

#### 🎯 Conversions de coordonnées

Flutter_map fournit des méthodes natives - **toujours les utiliser**:
```dart
// Géographique → Écran
Point screenPoint = camera.latLngToScreenPoint(latLng);

// Écran → Géographique
LatLng latLng = camera.pointToLatLng(screenPoint);
```

**Ne jamais** utiliser de formules Mercator approximatives.

### Autres caractéristiques techniques

- L'image conserve ses proportions d'origine
- Les transformations sont appliquées via Canvas avec matrice de transformation
- La sauvegarde utilise SharedPreferences avec encodage JSON et Base64
- L'overlay suit les mouvements et rotations de la carte en mode verrouillé
- Zoom adaptatif: `zoomScale = pow(2.0, currentZoom - referenceZoom)`
- La géolocalisation demande les permissions appropriées au démarrage
- Si la géolocalisation échoue, la carte se centre par défaut sur Paris

## Limitations connues

- Fonctionne uniquement avec des fichiers PNG
- Une seule image overlay à la fois
- La performance peut varier selon la taille de l'image

## Améliorations futures possibles

- Support de plusieurs overlays simultanés
- Support d'autres formats d'image (JPEG, SVG)
- Gestion par glisser-déposer pour le déplacement
- Ajustement de l'opacité de l'overlay
- Export/import de configurations

## Licence

Ce projet est fourni à des fins éducatives.
