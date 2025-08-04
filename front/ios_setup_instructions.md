# Configuration iOS - Autorisations et Google Maps

## 📋 Étapes de configuration

### 1. Configuration des clés API Google Maps

#### Option A: Via Info.plist (Recommandé)
1. Ouvrez `ios/Runner/Info.plist`
2. Remplacez `YOUR_GOOGLE_MAPS_API_KEY` par votre vraie clé API Google Maps
3. La clé se trouve à la ligne avec `<key>GMSApiKey</key>`

#### Option B: Via GoogleService-Info.plist
1. Téléchargez votre fichier `GoogleService-Info.plist` depuis Firebase Console
2. Placez-le dans `ios/Runner/`
3. Ajoutez-le au projet Xcode
4. La clé API sera automatiquement récupérée depuis ce fichier

### 2. Configuration Firebase pour iOS

1. **Télécharger GoogleService-Info.plist**
   - Allez sur [Firebase Console](https://console.firebase.google.com/)
   - Sélectionnez votre projet
   - Allez dans Paramètres du projet > Vos applications
   - Téléchargez le fichier `GoogleService-Info.plist` pour iOS

2. **Ajouter le fichier au projet**
   - Ouvrez le projet iOS dans Xcode: `open ios/Runner.xcworkspace`
   - Glissez-déposez `GoogleService-Info.plist` dans le dossier Runner
   - Assurez-vous que "Copy items if needed" est coché
   - Sélectionnez la target "Runner"

### 3. Vérification des permissions dans Info.plist

Les permissions suivantes ont été ajoutées automatiquement :

```xml
<!-- Localisation GPS -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Cette application a besoin d'accéder à votre localisation pour trouver les médecins les plus proches de vous.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Cette application a besoin d'accéder à votre localisation pour trouver les médecins les plus proches de vous.</string>

<!-- Notifications Push -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-fetch</string>
</array>

<!-- Clé API Google Maps -->
<key>GMSApiKey</key>
<string>YOUR_GOOGLE_MAPS_API_KEY</string>
```

### 4. Configuration Xcode

1. **Ouvrir le projet**
   ```bash
   cd ios
   open Runner.xcworkspace
   ```

2. **Vérifier les capabilities**
   - Sélectionnez le projet Runner
   - Allez dans l'onglet "Signing & Capabilities"
   - Ajoutez si nécessaire :
     - Push Notifications
     - Background Modes (Remote notifications, Background fetch)

3. **Vérifier le Bundle Identifier**
   - Assurez-vous que le Bundle Identifier correspond à celui configuré dans Firebase

### 5. Test des permissions

Utilisez le service de permissions créé :

```dart
import 'package:doctors_app/services/permissions_service.dart';

// Demander toutes les permissions
final permissionsService = PermissionsService();
final results = await permissionsService.requestAllPermissions();

print('Localisation: ${results['location']}');
print('Notifications: ${results['notification']}');
```

### 6. Test des cartes

Utilisez le service de cartes :

```dart
import 'package:doctors_app/services/maps_service.dart';

final mapsService = MapsService();

// Ouvrir avec une adresse
await mapsService.openMapsWithAddress("Dakar, Sénégal");

// Ouvrir avec des coordonnées
await mapsService.openMapsWithCoordinates(14.6928, -17.4467, label: "Dakar");

// Ouvrir les directions
await mapsService.openDirections(
  destinationLat: 14.6928,
  destinationLng: -17.4467,
  destinationLabel: "Clinique XYZ"
);
```

## 🔧 Dépannage

### Problème : "GoogleService-Info.plist not found"
- Vérifiez que le fichier est bien dans `ios/Runner/`
- Vérifiez qu'il est ajouté au projet Xcode
- Nettoyez et rebuilder le projet

### Problème : "API key not valid"
- Vérifiez que la clé API Google Maps est correcte
- Assurez-vous que l'API Maps SDK for iOS est activée
- Vérifiez les restrictions de la clé API

### Problème : Permissions refusées
- Les permissions sont demandées automatiquement
- L'utilisateur peut les modifier dans Réglages > Confidentialité
- Utilisez `openAppSettings()` pour rediriger vers les réglages

## 📱 Build et Test

1. **Nettoyer le projet**
   ```bash
   flutter clean
   cd ios
   rm -rf Pods
   rm Podfile.lock
   cd ..
   flutter pub get
   cd ios
   pod install
   ```

2. **Builder pour iOS**
   ```bash
   flutter build ios --release
   ```

3. **Tester sur simulateur**
   ```bash
   flutter run -d "iPhone 15 Pro"
   ```

## ✅ Checklist finale

- [ ] GoogleService-Info.plist ajouté au projet
- [ ] Clé API Google Maps configurée
- [ ] Permissions ajoutées dans Info.plist
- [ ] AppDelegate.swift configuré
- [ ] Capabilities activées dans Xcode
- [ ] Test des permissions réussi
- [ ] Test des cartes réussi
- [ ] Build iOS réussi

## 🔗 Liens utiles

- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Google Maps iOS SDK](https://developers.google.com/maps/documentation/ios-sdk/start)
- [iOS Permissions Guide](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)
