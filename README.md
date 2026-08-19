# AILA Beauty Boutique

Flutter mobile app for AILA Beauty Boutique — a soft-luxury cosmetics store.

## What It Includes

- Product browsing and category discovery
- Search and wishlist management
- Cart and checkout flows
- Orders, wallet, and notifications
- Backend integration with `https://hindam.ly`

## Run Locally

```bash
flutter pub get
flutter run
```

## Build Android Release

Keep `MAPS_API_KEY` in `android/local.properties` or set `DART_MAPS_API_KEY`
in the shell environment. Do not add `.env` to Flutter assets.

```powershell
.\scripts\build_android_release.ps1
```

For a Play Store bundle:

```powershell
.\scripts\build_android_release.ps1 -Target appbundle
```

Manual equivalent:

```bash
flutter build apk --release --dart-define=DART_MAPS_API_KEY=YOUR_KEY
```

## Build iOS Release

On the Mac or CI machine, copy the template and set the real iOS Google Maps
key:

```bash
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
```

Then build:

```bash
./scripts/build_ios_release.sh
```
"# aila-app" 
"# aila_app" 
