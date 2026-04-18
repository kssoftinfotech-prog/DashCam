import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  cameras = await availableCameras();
  runApp(const DashcamApp());
}

class DashcamApp extends StatelessWidget {
  const DashcamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DashcamScreen(),
    );
  }
}

class DashcamScreen extends StatefulWidget {
  const DashcamScreen({super.key});

  @override
  State<DashcamScreen> createState() => _DashcamScreenState();
}

class _DashcamScreenState extends State<DashcamScreen> {
  CameraController? controller;

  bool isRecording = false;

  int recordDuration = 30;
  int maxFiles = 5;

  Timer? loopTimer;

  static const platform = MethodChannel('media_scanner');

  final TextEditingController _durationController = TextEditingController(text: "30");
  final TextEditingController _maxFilesController = TextEditingController(text: "5");

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    controller?.dispose();
    _durationController.dispose();
    _maxFilesController.dispose();
    super.dispose();
  }

  Future<void> init() async {
    await requestPermissions();

    // Keep screen on while the app is running
    WakelockPlus.enable();

    // Hide status bar and navigation bar for true full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    controller = CameraController(
      cameras.first,
      ResolutionPreset.high, // Higher resolution for dashcam
      enableAudio: true,
    );

    await controller!.initialize();
    if (mounted) setState(() {});
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: "Segment Duration (seconds)"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _maxFilesController,
              decoration: const InputDecoration(labelText: "Max Number of Files"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                recordDuration = int.tryParse(_durationController.text) ?? 30;
                maxFiles = int.tryParse(_maxFilesController.text) ?? 5;
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13 (API 33) and above
      await [
        Permission.camera,
        Permission.microphone,
        Permission.videos,
        Permission.photos,
      ].request();
    } else {
      await [
        Permission.camera,
        Permission.microphone,
        Permission.storage,
      ].request();
    }
  }

  void startLoopRecording() {
    isRecording = true;
    setState(() {});
    _runRecordingLoop();
  }

  Future<void> _runRecordingLoop() async {
    // Start the first segment
    await recordSegment();

    while (isRecording) {
      await Future.delayed(Duration(seconds: recordDuration));
      if (!isRecording) break;
      await recordSegment();
    }
  }

  Future<void> stopLoopRecording() async {
    isRecording = false;
    loopTimer?.cancel(); // Safety for old code
    if (controller != null && controller!.value.isRecordingVideo) {
      try {
        final file = await controller!.stopVideoRecording();
        await saveAndManageFiles(file.path);
      } catch (e) {
        debugPrint("Stop recording error: $e");
      }
    }
    setState(() {});
  }

  Future<void> recordSegment() async {
    if (controller == null || !controller!.value.isInitialized || !isRecording) return;

    try {
      // If already recording, stop it and save it
      if (controller!.value.isRecordingVideo) {
        final file = await controller!.stopVideoRecording();
        // Start saving in background so we can start the next recording immediately
        saveAndManageFiles(file.path);
      }

      // Start the next recording
      if (isRecording) {
        await controller!.startVideoRecording();
      }
    } catch (e) {
      debugPrint("Recording error: $e");
    }
  }

  Future<void> saveAndManageFiles(String tempPath) async {
    try {
      // Using a more standard path for Android
      final Directory dir = Directory('/storage/emulated/0/Movies/Dashcam');

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fileName = "VID_${DateTime.now().millisecondsSinceEpoch}.mp4";
      final newPath = p.join(dir.path, fileName);

      final File tempFile = File(tempPath);
      if (await tempFile.exists()) {
        final newFile = await tempFile.copy(newPath);
        // Important: Delete temp file after copy
        await tempFile.delete();

        debugPrint("Video saved to: ${newFile.path}");

        // 🔥 Notify Android Gallery
        await platform.invokeMethod('scanFile', {"path": newFile.path});
      }

      await deleteOldFiles(dir);
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  Future<void> deleteOldFiles(Directory dir) async {
    try {
      final List<FileSystemEntity> entities = dir.listSync();
      
      // Filter for our dashcam files only
      final List<File> dashcamFiles = entities
          .whereType<File>()
          .where((file) {
            final name = p.basename(file.path);
            return name.startsWith("VID_") && name.toLowerCase().endsWith(".mp4");
          })
          .toList();

      debugPrint("Found ${dashcamFiles.length} dashcam videos. (Limit: $maxFiles)");

      if (dashcamFiles.length > maxFiles) {
        // Sort by the timestamp in the filename (most reliable)
        dashcamFiles.sort((a, b) {
          try {
            final tsA = int.parse(p.basenameWithoutExtension(a.path).split('_').last);
            final tsB = int.parse(p.basenameWithoutExtension(b.path).split('_').last);
            return tsA.compareTo(tsB);
          } catch (_) {
            // Fallback to file system modification time
            return a.lastModifiedSync().compareTo(b.lastModifiedSync());
          }
        });

        int toDeleteCount = dashcamFiles.length - maxFiles;

        for (int i = 0; i < toDeleteCount; i++) {
          final fileToDelete = dashcamFiles[i];
          final pathToDelete = fileToDelete.path;
          
          try {
            await fileToDelete.delete();
            debugPrint("Successfully deleted: $pathToDelete");
            
            // Notify gallery that the file is gone
            await platform.invokeMethod('scanFile', {"path": pathToDelete});
          } catch (e) {
            debugPrint("Failed to delete file from disk: $pathToDelete. Error: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Critical error in deleteOldFiles: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Calculate the scale to fill the screen
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full Screen Camera Preview
          SizedBox.expand(
            child: ClipRect(
              child: Transform.scale(
                scale: scale,
                child: Center(
                  child: CameraPreview(controller!),
                ),
              ),
            ),
          ),

          // 2. Top Overlay (App Name / Status)
          Positioned(
            top: 40,
            left: 20,
            child: Row(
              children: [
                GestureDetector(
                  onTap: isRecording ? null : _showSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          "SETTINGS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        if (!isRecording) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.settings, color: Colors.white, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Recording Indicator
          if (isRecording)
            Positioned(
              top: 45,
              right: 20,
              child: Row(
                children: [
                  const Icon(Icons.circle, color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    "REC",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                ],
              ),
            ),

          // 4. Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Start Button
                FloatingActionButton(
                  heroTag: "start",
                  backgroundColor: isRecording ? Colors.grey : Colors.green,
                  onPressed: isRecording ? null : startLoopRecording,
                  child: const Icon(Icons.play_arrow, size: 30),
                ),
                // Stop Button
                FloatingActionButton(
                  heroTag: "stop",
                  backgroundColor: isRecording ? Colors.red : Colors.grey,
                  onPressed: isRecording ? stopLoopRecording : null,
                  child: const Icon(Icons.stop, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}