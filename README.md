# Pumply App (Starter)

This repository contains a **minimal Flutter starter** for Pumply.  
You can upload these files to GitHub and connect Codemagic to build the APK.

## Quick steps

1. Upload all files/folders at the **root** of your repo (same level as `pubspec.yaml`).
2. Codemagic will run `flutter create .` during the build if platform folders are missing.
3. To run locally:
   ```bash
   flutter pub get
   flutter run
   ```
4. Add your UI in `lib/` and assets in `assets/images/`.

> Note: Do **not** upload `build/` or `.dart_tool/` to GitHub.