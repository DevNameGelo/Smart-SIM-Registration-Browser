# Smart SIM Registration Browser

A dedicated Flutter Android browser that opens the official Smart SIM registration portal: https://simreg.smart.com.ph/

## Why this app may help

Unlike a plain embedded browser, this app handles Android WebView permission requests and asks Android for camera permission when the official Smart site requests camera access. It also provides WebView navigation, JavaScript, DOM storage, cookies, file upload support via the WebView plugin, reload controls, error feedback, and permission help.

## Important limits

- It cannot bypass Android's permission prompts or Smart's own website/server checks.
- Camera access is granted only to HTTPS pages on `smart.com.ph` and its subdomains; other origins are denied.
- If the Android permission was permanently denied, enable Camera in Android Settings > Apps > Smart SIM Registration Browser > Permissions.
- The portal may still have outages, image size/format restrictions, or verification rules outside the app's control.
- The app is an independent browser helper, not an official Smart Communications app. Do not share OTPs or registration data with anyone.

## Build APK using GitHub Actions

Push this project to a GitHub repository. The workflow creates the Android platform folder when missing, installs Flutter dependencies, and builds a debug APK. Download the `smart-sim-registration-debug-apk` artifact from Actions.

## Local build

```bash
flutter pub get
flutter build apk --debug
```

Minimum Android API: 21 (Android 5.0); Android 10 and newer are supported by the Flutter WebView runtime. Actual camera and upload behavior depends on Android System WebView/Chrome being updated and the Smart portal itself.
