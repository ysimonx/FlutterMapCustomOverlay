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
    ├── custom_image_layer.dart        # Layer personnalisé (non utilisé)
    └── image_overlay_widget.dart      # Widget d'affichage de l'overlay
```

## Dépendances principales

- **flutter_map** : Affichage de cartes OpenStreetMap
- **latlong2** : Gestion des coordonnées géographiques
- **geolocator** : Géolocalisation de l'utilisateur
- **file_picker** : Sélection de fichiers
- **image** : Traitement d'images
- **shared_preferences** : Persistance locale des données

## Notes techniques

- L'image conserve ses proportions d'origine
- Les transformations (rotation, échelle, position) sont appliquées via Canvas
- La sauvegarde utilise SharedPreferences avec encodage JSON et Base64
- L'overlay suit les mouvements de la carte quand il est verrouillé
- La géolocalisation demande les permissions appropriées au démarrage (Android et iOS)
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
