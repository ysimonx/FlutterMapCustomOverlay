# Flutter Map Custom Overlay

Application Flutter multiplateforme (Web, Android, iOS) permettant d'ajouter des overlays d'images personnalisées sur une carte OpenStreetMap.


https://github.com/user-attachments/assets/53cff802-3ea9-432c-8596-2c0be757b453


## Fonctionnalités

- Navigation sur une carte OpenStreetMap interactive
- **Géolocalisation automatique** : La carte se centre automatiquement sur votre position actuelle au démarrage
- **Contrôles de carte** :
  - Boutons de zoom avant/arrière
  - Bouton pour recentrer sur votre position actuelle
- Ajout d'images PNG en overlay sur la carte
- Manipulation de l'overlay :
  - **Déplacement** : glisser-déposer direct en mode édition
  - **Rotation** : boutons ou poignée interactive (verte au-dessus de l'image)
  - **Redimensionnement (zoom)** : boutons ou poignées aux 4 coins (bleues)
  - Ajustement de l'opacité (0-100%)
- Conservation des proportions de l'image d'origine
- Affichage des coordonnées GPS (latitude/longitude) aux 4 coins de l'image
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

**Boutons de contrôle de la carte** :
- *En haut à droite* :
  - **+** : Zoom avant sur la carte
  - **-** : Zoom arrière sur la carte
  - **📍** : Recentrer la carte sur votre position actuelle (ou sur l'overlay si verrouillé)
- *En bas à gauche* :
  - **Rotation gauche** : Pivoter la carte de 30° dans le sens anti-horaire
  - **Rotation droite** : Pivoter la carte de 30° dans le sens horaire
  - **Boussole** : Réinitialiser la rotation à 0° (nord vers le haut)
  - **Indicateur d'angle** : Affiche l'angle de rotation actuel de la carte en degrés

### 2. Ajouter une image

1. Cliquez sur le bouton "Ajouter une image" (flottant en bas à droite)
2. Sélectionnez un fichier PNG depuis votre appareil
3. L'image apparaît au centre de la carte actuelle

### 3. Éditer l'overlay

Une fois l'image ajoutée, le mode édition s'active automatiquement. Vous disposez de **deux méthodes** pour manipuler l'image :

#### Méthode 1 : Manipulation directe (poignées)
- **Déplacement** : Cliquez et glissez n'importe où sur l'image
- **Rotation** : Utilisez la poignée verte au-dessus de l'image (reliée par une ligne bleue)
- **Redimensionnement** : Utilisez les poignées bleues aux 4 coins de l'image

#### Méthode 2 : Panneau de contrôle (boutons)
Un panneau de contrôle compact s'affiche en bas de l'écran avec :
- **Rotation** : Boutons avec flèches circulaires (rotation par pas de 1°)
- **Échelle** : Boutons zoom + et - (ajustement par pas de 0.05)
- **Déplacement** : Boutons avec flèches directionnelles (déplacement de 10 pixels)
- **Opacité** : Curseur pour ajuster la transparence de l'image (0-100%)

En mode édition, l'overlay affiche :
- Une bordure bleue
- 4 poignées bleues aux coins (pour le redimensionnement)
- 4 poignées blanches au milieu des côtés (visuelles)
- 1 poignée verte au-dessus (pour la rotation)
- Les coordonnées GPS (latitude/longitude) aux 4 coins de l'image

### 4. Sauvegarder

Cliquez sur l'icône de sauvegarde dans la barre d'application pour enregistrer la configuration actuelle de l'overlay.

### 5. Verrouiller

Cliquez sur l'icône de cadenas pour verrouiller l'overlay :
- En mode verrouillé, l'overlay devient fixe géographiquement
- Vous pouvez naviguer normalement sur la carte (zoom, déplacement, rotation)
- L'overlay suit automatiquement les mouvements et rotations de la carte
- Le mode édition se désactive automatiquement lors du verrouillage
- Quand vous déverrouillez, la rotation actuelle de l'overlay est conservée

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
- **Rotation de référence de la carte en DEGRÉS** (pour le mode verrouillé)
- **Opacité** (0.0-1.0)

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
- Mode édition avec poignées visuelles interactives :
  - Poignée de rotation (verte, au-dessus de l'image)
  - Poignées de redimensionnement (bleues, aux 4 coins)
  - Glisser-déposer pour le déplacement
- Détection des interactions tactiles/souris avec calculs géométriques
- Désactivation temporaire de la carte pendant les manipulations de l'overlay

## Dépendances principales

- **flutter_map** : Affichage de cartes OpenStreetMap
- **latlong2** : Gestion des coordonnées géographiques
- **geolocator** : Géolocalisation de l'utilisateur
- **file_picker** : Sélection de fichiers
- **image** : Traitement d'images
- **shared_preferences** : Persistance locale des données

## Notes techniques

### Interaction utilisateur avec l'overlay

L'overlay propose **deux modes d'interaction** en mode édition :

#### 1. Manipulation directe (drag & drop, poignées)
- **Glisser-déposer** : Cliquez n'importe où sur l'image et déplacez-la
- **Poignée de rotation** : Cercle vert au-dessus de l'image, relié par une ligne bleue
  - Distance de détection agrandie pour faciliter l'utilisation
  - Rotation en temps réel suivant le mouvement de la souris/doigt
- **Poignées de redimensionnement** : Cercles bleus aux 4 coins
  - Calcul de la distance entre le centre et le coin pour déterminer le facteur d'échelle
  - Redimensionnement proportionnel en temps réel

#### 2. Interactions prioritaires
Le système détecte les interactions dans cet ordre :
1. **Coins** (priorité 1) : Redimensionnement
2. **Poignée verte** (priorité 2) : Rotation
3. **Ailleurs sur l'image** (priorité 3) : Déplacement

Pendant une interaction, la carte est temporairement désactivée pour éviter les conflits.

#### 3. Calculs géométriques
- **Détection de poignée** : Calcul de distance euclidienne avec zone de détection élargie
- **Transformation inverse** : Pour détecter les clics, les coordonnées écran sont transformées dans le système local de l'image (inversion de l'échelle puis de la rotation)
- **Affichage des coordonnées GPS** : Les 4 coins de l'image affichent leur latitude/longitude en temps réel

### Gestion des rotations

⚠️ **IMPORTANT**: Ce projet utilise **deux systèmes d'unités** pour les rotations.

#### 1. DEGRÉS (0-360°)
**Utilisé pour:**
- Stockage dans `ImageOverlayData.rotation`
- Interface utilisateur (boutons ±1°, affichage)
- Paramètre de la méthode `_rotateImage(double deltaDegre)`
- Rotation de la carte (`MapCamera.rotation` stocke maintenant en degrés)
- `ImageOverlayData.referenceMapRotation` (référence pour le mode verrouillé)

**Raison:** Plus intuitif pour l'utilisateur (30° est plus parlant que 0.524 radians)

#### 2. RADIANS (0-2π)
**Utilisé pour:**
- `Canvas.rotate()` (API de dessin Flutter standard)
- Calculs trigonométriques (sin, cos, atan2)

**Raison:** Standard pour les APIs de bas niveau et les calculs mathématiques

⚠️ **Note importante** : Le projet a évolué pour utiliser principalement des degrés. `MapCamera.rotation` retourne maintenant des degrés directement.

### Conversions

```dart
// Degrés → Radians
double radians = degrees * (pi / 180);

// Radians → Degrés
double degrees = radians * (180 / pi);
```

### Flux de rotation de l'overlay

#### A. Par boutons (±1°)
1. **Utilisateur clique sur bouton de rotation**
   ```dart
   _rotateImage(1.0); // Delta en degrés
   ```

2. **Mise à jour du modèle (en degrés)**
   ```dart
   rotation = currentRotation + deltaDegre; // Stocké en degrés
   ```

#### B. Par poignée verte (drag & drop)
1. **Détection du clic sur la poignée de rotation**
   - Calcul de la distance entre le point cliqué et la position de la poignée verte
   - Zone de détection élargie (1.5x le rayon) pour faciliter l'utilisation

2. **Suivi du mouvement en temps réel**
   ```dart
   // Calcul de l'angle actuel entre le centre et le curseur
   final currentAngle = atan2(dy, dx) * 180 / pi;

   // Calcul de la différence d'angle depuis le début du drag
   final angleDelta = currentAngle - _initialAngle!;

   // Nouvelle rotation = rotation initiale + delta
   final newRotation = _initialRotation! + angleDelta;
   ```

3. **Rendu dans ImageOverlayPainter (conversion en radians)**
   ```dart
   canvas.rotate(finalRotationDegrees * (pi / 180)); // Conversion pour Canvas
   ```

4. **En mode verrouillé: synchronisation avec la carte**
   ```dart
   // La carte rotate en degrés
   final mapDeltaDegrees = currentMapRotation - referenceMapRotation;

   // Combiné avec la rotation de l'overlay (en degrés)
   finalRotation = overlayRotation + mapDeltaDegrees;
   ```

### Rotation de la carte

Les boutons de rotation de la carte (en bas à gauche) utilisent ±30°:
```dart
void _rotateMapLeft() {
  final currentRotation = mapController.camera.rotation; // en degrés
  const delta = -30; // en degrés
  final newRotation = currentRotation + delta;
  mapController.moveAndRotate(center, zoom, newRotation);
}
```

**Contrôles de rotation de la carte** :
- **Bouton gauche** : Rotation anti-horaire de 30°
- **Bouton droit** : Rotation horaire de 30°
- **Bouton boussole** : Réinitialisation à 0° (nord vers le haut)
- **Indicateur d'angle** : Affiche en temps réel la rotation actuelle de la carte en degrés dans un encadré blanc

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
    'opacity': opacity, // opacité (0.0-1.0) ✓
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
- La sauvegarde utilise SharedPreferences avec encodage JSON et Base64 (inclut l'opacité)
- L'overlay suit les mouvements et rotations de la carte en mode verrouillé
- Zoom adaptatif: `zoomScale = pow(2.0, currentZoom - referenceZoom)`
- La géolocalisation demande les permissions appropriées au démarrage
- Si la géolocalisation échoue, la carte se centre par défaut sur ITER Cadarache
- En mode verrouillé, le bouton de position centre la carte sur l'overlay (pas sur la position GPS)
- Gestion des événements pointer (PointerDown, PointerMove, PointerUp) pour les interactions tactiles/souris
- Désactivation automatique des interactions carte pendant la manipulation de l'overlay (`_isInteractingWithOverlay`)
- StreamBuilder pour forcer le rebuild de l'overlay lors des changements de carte (zoom, déplacement, rotation)

## Limitations connues

- Fonctionne uniquement avec des fichiers PNG
- Une seule image overlay à la fois
- La performance peut varier selon la taille de l'image

## Améliorations futures possibles

- Support de plusieurs overlays simultanés
- Support d'autres formats d'image (JPEG, SVG)
- ~~Gestion par glisser-déposer pour le déplacement~~ ✅ **Implémenté**
- ~~Ajustement de l'opacité de l'overlay~~ ✅ **Implémenté**
- ~~Manipulation par poignées (rotation, zoom)~~ ✅ **Implémenté**
- Export/import de configurations
- Annulation/Rétablissement (undo/redo)
- Historique des modifications

## Licence

Ce projet est fourni à des fins éducatives.
