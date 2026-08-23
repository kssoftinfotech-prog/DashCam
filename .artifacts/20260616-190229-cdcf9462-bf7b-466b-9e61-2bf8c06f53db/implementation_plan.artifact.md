# Crash Detection and Incident Locking Implementation

Implement automatic impact detection using the accelerometer to "lock" and protect critical video files from deletion.

## User Review Required

> [!IMPORTANT]
> - **Threshold**: The impact threshold is set to **2.5G**. This is a standard balance to detect collisions while ignoring minor road bumps.
> - **Locked Files**: Files marked as incidents will be prefixed with `EMG_` (Emergency). These files **will never be automatically deleted** by the app. The user must manually delete them to free up space.

## Proposed Changes

### Flutter Core

#### [main.dart](file:///C:/Users/sujil/StudioProjects/DASHCAM/lib/main.dart)

- Add `sensors_plus` import.
- Implement `_initAccelerometer()` to listen for sudden impacts.
- Track `lastVideoPath` and `currentVideoPath` to protect both when an impact occurs.
- Add `_lockIncidentFiles()` to rename relevant files with `EMG_` prefix.
- Update `_deleteOldFiles()` to only target files starting with `VID_`, ignoring `EMG_`.
- Add a UI indicator (Red banner) that appears when an incident is detected.

```dart
// Logic for impact detection
void _onAccelerometerEvent(AccelerometerEvent event) {
  double gForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z) / 9.81;
  if (gForce > 2.5) {
    _lockIncidentFiles();
  }
}
```

## Verification Plan

### Automated Tests
- `flutter analyze` to ensure code correctness.

### Manual Verification
- Start recording.
- Shake the phone vigorously (simulating a 2.5G impact).
- Verify the "Incident Detected" UI appears.
- Check the storage folder to ensure the current and previous videos are renamed with the `EMG_` prefix.
- Verify that these `EMG_` files are not deleted when storage gets full (test by lowering the 500MB buffer temporarily).
