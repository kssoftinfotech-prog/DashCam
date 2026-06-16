# Fix PlatformException for SharedPreferences in Release Build

The `PlatformException` (channel-error) in the Play Store version is caused by R8/ProGuard stripping or obfuscating classes required by the `shared_preferences` plugin, specifically the Pigeon-generated platform channel interfaces.

## User Review Required

> [!IMPORTANT]
> I am changing `compileSdk` from 36 to 35. SDK 36 is not yet a stable release, and using it might cause unexpected behavior with build tools like R8. SDK 35 corresponds to Android 15.

## Proposed Changes

### Android Configuration

#### [proguard-rules.pro](file:///C:/Users/sujil/StudioProjects/DASHCAM/android/app/proguard-rules.pro)

- Fix the typo in `io.flutter.plugins.shared_preferences` (added missing underscore).
- Add more explicit rules for Pigeon-generated classes to prevent them from being stripped.
- Ensure all members are kept for these critical classes.

```diff
-# 2. Fix SharedPreferences (dev.flutter.pigeon.shared_preferences_android)
-# This is the exact fix for the error in your screenshot
--keep class dev.flutter.pigeon.** { *; }
--keep class io.flutter.plugins.sharedpreferences.** { *; }
+# 2. Fix SharedPreferences and Pigeon-based plugins
+-keep class dev.flutter.pigeon.** { *; }
+-keep interface dev.flutter.pigeon.** { *; }
+-keep class io.flutter.plugins.shared_preferences.** { *; }
```

#### [build.gradle.kts](file:///C:/Users/sujil/StudioProjects/DASHCAM/android/app/build.gradle.kts)

- Downgrade `compileSdk` to 35 (Android 15) to ensure compatibility with stable Flutter and plugin tools.

```diff
 android {
     namespace = "com.kssoft.dashcam"
-    compileSdk = 36
+    compileSdk = 35
```

---

### Flutter Core

#### [main.dart](file:///C:/Users/sujil/StudioProjects/DASHCAM/lib/main.dart)

- Convert `DashcamApp` to a `StatefulWidget` to ensure `_initAppData()` is only called once and its Future is preserved. This prevents redundant calls and potential race conditions during startup.
- Improve error handling in `_initAppData` to catch `PlatformException` more robustly.

```dart
class DashcamApp extends StatefulWidget {
  const DashcamApp({super.key});

  @override
  State<DashcamApp> createState() => _DashcamAppState();
}

class _DashcamAppState extends State<DashcamApp> {
  late Future<Map<String, dynamic>> _initDataFuture;

  @override
  void initState() {
    super.initState();
    _initDataFuture = _initAppData();
  }
  ...
}
```

## Verification Plan

### Automated Tests
- I will run `flutter analyze` to ensure no regressions in Dart code.

### Manual Verification
- Since this issue only occurs in **Release builds** (ProGuard/R8), I recommend building a release APK and testing it on a physical device.
- Run: `flutter build apk --release`
- Install the resulting APK: `flutter install`
- Check if the app starts without the error message.
- If the error persists, check `adb logcat` for more detailed stripping warnings.
