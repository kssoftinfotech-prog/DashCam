# Smart Storage Management Implementation

Implement a logic where the app records until the device's storage is nearly full, then automatically deletes the oldest segments to make room for new ones.

## User Review Required

> [!IMPORTANT]
> The "Max Number of Files" setting will be removed as storage management is now automatic.
> A 500MB safety buffer will be maintained to prevent device performance issues.

## Proposed Changes

### Android Platform

#### [MainActivity.kt](file:///C:/Users/sujil/StudioProjects/DASHCAM/android/app/src/main/kotlin/com/kssoft/dashcam/MainActivity.kt)

- Add `getFreeDiskSpace` method to the platform channel to return available bytes.

```kotlin
                    "getFreeDiskSpace" -> {
                        try {
                            val path = Environment.getExternalStorageDirectory().path
                            val stat = StatFs(path)
                            val bytesAvailable = stat.blockSizeLong * stat.availableBlocksLong
                            result.success(bytesAvailable)
                        } catch (e: Exception) {
                            result.error("STORAGE_ERROR", "Failed to get storage info", e.message)
                        }
                    }
```

---

### Flutter Core

#### [main.dart](file:///C:/Users/sujil/StudioProjects/DASHCAM/lib/main.dart)

- Remove `maxFiles` state variable and associated controllers.
- Update `_deleteOldFiles` to check disk space using the new platform method.
- Maintain a 500MB buffer before deleting old files.
- Simplify Settings dialog to remove "Max Number of Files".

```dart
  Future<void> _deleteOldFiles(Directory dir) async {
    try {
      const int minFreeSpace = 500 * 1024 * 1024; // 500 MB Buffer

      while (true) {
        final int? freeSpace = await platform.invokeMethod<int>('getFreeDiskSpace');
        if (freeSpace == null || freeSpace > minFreeSpace) break;

        final List<FileSystemEntity> entities = dir.listSync();
        final List<File> dashcamFiles = entities
            .whereType<File>()
            .where((file) => p.basename(file.path).startsWith("VID_"))
            .toList();

        if (dashcamFiles.isEmpty) break;

        dashcamFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        await dashcamFiles.first.delete();
        await platform.invokeMethod('scanFile', {"path": dashcamFiles.first.path});
      }
    } catch (e) {
      debugPrint("Cleanup error: $e");
    }
  }
```

## Verification Plan

### Automated Tests
- `flutter analyze` to ensure code correctness.

### Manual Verification
- Verify the "Max Number of Files" setting is gone.
- Verify video recording still works.
- Verify that older files are deleted when storage is low (can be simulated by lowering the buffer threshold temporarily).
