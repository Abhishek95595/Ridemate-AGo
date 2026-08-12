# AGo

A professional carpooling platform built with Flutter and Firebase.

## Getting Started

This project uses Flutter with Riverpod for state management, Firebase
(Auth, Firestore, Storage, Messaging) for the backend, and Google Maps for
ride routing and live location tracking.

A few resources if you're new to Flutter:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## Local setup

Two files are required but **not committed to git** (each developer/machine
needs their own copy):

### `android/local.properties`
```properties
flutter.sdk=<path to your Flutter SDK>
sdk.dir=<path to your Android SDK>
MAPS_API_KEY=<Google Maps API key, restricted to this app's package + SHA-1s>
```

### `android/key.properties` (required to produce a release build)
```properties
storePassword=<release keystore password>
keyPassword=<release keystore password>
keyAlias=ago-upload
storeFile=../keystore/ago-release-upload.jks
```
The keystore itself (`android/keystore/ago-release-upload.jks`) and its
password are not in git either — restore them from the
password manager entry for "AGo release keystore". Losing this keystore
means the app can never be updated on the Play Store again.

### Running the app
```
flutter pub get
cp dart_defines.json.example dart_defines.json
# Fill MAPS_API_KEY, PLACES_API_KEY, and ROUTES_API_KEY, then:
flutter run --dart-define-from-file=dart_defines.json
```
The `--dart-define-from-file` values are required separately from `local.properties` — the
Maps key is read by native Android (via `local.properties` +
`AndroidManifest.xml`) for the map view itself, and by Dart code (via
`--dart-define-from-file`) for Places/Directions/Geocoding REST calls. See `lib/config/api_config.dart`.

## Before publishing to the Play Store

See [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) for the full pre-submission
review, what's already been fixed, and what's still outstanding.
