#!/usr/bin/env sh
# One-time setup: generates the android/ platform folder (not included in the
# source archive) and enables internet access for release builds.
# Run from the project root:  sh scripts/setup_android.sh
set -e
flutter create --platforms=android --project-name stock_scope --org com.example.stockscope .
# `flutter create` may add a template test that references a different app.
[ -f test/widget_test.dart ] && rm test/widget_test.dart
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
flutter pub get
echo "Done. Next: flutter analyze && flutter test && flutter run"
