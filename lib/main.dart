import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:intl/intl.dart';

late List<CameraDescription> cameras;

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation to landscape mode
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    try {
      cameras = await availableCameras();
    } catch (e) {
      debugPrint("Available cameras error: $e");
      cameras = []; // Initialize as empty list to avoid late initialization error
    }
    
    runApp(const DashcamApp());
  } catch (e) {
    debugPrint("Critical startup error: $e");
  }
}

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: FutureBuilder<Map<String, dynamic>>(
        future: _initDataFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text("Error starting app: ${snapshot.error}", textAlign: TextAlign.center),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final data = snapshot.data!;
          final isFirstTime = data['first_time'] as bool;
          final camerasAvailable = data['cameras_available'] as bool;

          if (!camerasAvailable) {
            return const Scaffold(
              body: Center(
                child: Text("No cameras found on this device.", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            );
          }

          if (isFirstTime) {
            return const OnboardingScreen();
          }
          return const DashcamScreen();
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _initAppData() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 5));
      return {
        'first_time': prefs.getBool('first_time') ?? true,
        'cameras_available': cameras.isNotEmpty,
      };
    } catch (e) {
      debugPrint("Settings load timeout: $e");
      return {
        'first_time': false, // Assume not first time to get into dashcam mode
        'cameras_available': true, // Assume true to try initializing
      };
    }
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      "title": "Welcome to Dashcam",
      "description": "Your reliable companion for every journey.",
      "icon": "🚗",
    },
    {
      "title": "Customizable Recording",
      "description": "You can set the duration of each video in the settings. The app records continuously for the duration you choose.",
      "icon": "⚙️",
    },
    {
      "title": "Smart Storage Logic",
      "description": "The app automatically manages space, keeping a 500MB safety buffer to ensure your phone stays smooth and stable.",
      "icon": "🔄",
    },
    {
      "title": "Maximized History",
      "description": "Old files are deleted only when storage is full, maximizing your recording history based on your phone's memory.",
      "icon": "📸",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(
                        _pages[index]["icon"]!,
                        style: const TextStyle(fontSize: 120),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pages[index]["title"]!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(right: 40),
                          child: Text(
                            _pages[index]["description"]!,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index ? Colors.white : Colors.green,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_currentPage == _pages.length - 1) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('first_time', false);
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const DashcamScreen()),
                            );
                          }
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(_currentPage == _pages.length - 1 ? "Get Started" : "Next"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  int recordDuration = 120;
  ResolutionPreset selectedResolution = ResolutionPreset.high;

  Timer? _clockTimer;
  String _currentTime = "";

  static const platform = MethodChannel('media_scanner');

  final TextEditingController _durationController = TextEditingController(text: "120");

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _clockTimer?.cancel();
    controller?.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> init() async {
    try {
      await requestPermissions();

      // Keep screen on while the app is running
      WakelockPlus.enable();

      // Hide status bar and navigation bar for true full screen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // Start clock timer for the UI overlay
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _currentTime = DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
          });
        }
      });

      if (cameras.isEmpty) {
        debugPrint("No cameras available to initialize");
        return;
      }

      controller = CameraController(
        cameras.first,
        selectedResolution,
        enableAudio: true,
      );

      await controller!.initialize();
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Initialization error: $e");
    }
  }

  void _showSettings() { 
    ResolutionPreset tempResolution = selectedResolution;
    int tempDuration = recordDuration;

    showDialog(
      context: context,
      builder: (context) => Theme(
        data: ThemeData.light(),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
            title: const Text("Settings"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Video Duration
              const Text("Video Duration", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _presetButton("1m", 60, tempDuration, (v) => setDialogState(() => tempDuration = v)),
                  _presetButton("2m", 120, tempDuration, (v) => setDialogState(() => tempDuration = v)),
                  _presetButton("3m", 180, tempDuration, (v) => setDialogState(() => tempDuration = v)),
                  _presetButton("5m", 300, tempDuration, (v) => setDialogState(() => tempDuration = v)),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (tempDuration > 10) setDialogState(() => tempDuration -= 10);
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 30),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("$tempDuration sec", style: const TextStyle(fontSize: 18)),
                  ),
                  IconButton(
                    onPressed: () => setDialogState(() => tempDuration += 10),
                    icon: const Icon(Icons.add_circle_outline, size: 30),
                  ),
                ],
              ),

              const Divider(height: 40),

              // 2. Resolution
              const Text("Camera Resolution", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ResolutionPreset>(
                    isExpanded: true,
                    value: tempResolution,
                    items: const [
                      DropdownMenuItem(value: ResolutionPreset.low, child: Text("Low (240p)")),
                      DropdownMenuItem(value: ResolutionPreset.medium, child: Text("Medium (480p)")),
                      DropdownMenuItem(value: ResolutionPreset.high, child: Text("High (720p)")),
                      DropdownMenuItem(value: ResolutionPreset.veryHigh, child: Text("Very High (1080p)")),
                      DropdownMenuItem(value: ResolutionPreset.ultraHigh, child: Text("4K (2160p)")),
                      DropdownMenuItem(value: ResolutionPreset.max, child: Text("Max Available")),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => tempResolution = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                );
              },
              child: const Text("Show Tutorial"),
            ),
            ElevatedButton(
              onPressed: () async {
                final oldResolution = selectedResolution;
                final oldController = controller;

                if (oldResolution != tempResolution) {
                  setState(() {
                    controller = null;
                  });
                }

                setState(() {
                  recordDuration = tempDuration;
                  selectedResolution = tempResolution;
                  _durationController.text = tempDuration.toString();
                });
                Navigator.pop(context);

                if (oldResolution != selectedResolution) {
                  await oldController?.dispose();
                  await init();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text("Save Settings"),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _presetButton(String label, int value, int current, Function(int) onTap) {
    bool isSelected = value == current;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: OutlinedButton(
          onPressed: () => onTap(value),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: isSelected ? Colors.black : Colors.transparent,
            foregroundColor: isSelected ? Colors.white : Colors.black,
            side: BorderSide(color: isSelected ? Colors.black : Colors.grey.shade300),
          ),
          child: Text(label),
        ),
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

  Future<void> startLoopRecording() async {
    if (isRecording) return;

    final Directory dir = Directory('/storage/emulated/0/Movies/Dashcam');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    try {
      isRecording = true;
      setState(() {});
      
      _runRecordingLoop(dir.path);
    } catch (e) {
      debugPrint("Recording start error: $e");
      isRecording = false;
      setState(() {});
    }
  }

  Future<void> _runRecordingLoop(String folderPath) async {
    while (isRecording) {
      try {
        if (controller == null || !controller!.value.isInitialized) break;

        final startTime = DateTime.now();
        
        // 1. Start the recording
        await controller!.startVideoRecording();
        
        // 2. Wait for the duration
        // We wait for the full duration. The slight overhead of stopping/starting 
        // is now minimized by removing the 'prepareForVideoRecording' call inside the loop.
        await Future.delayed(Duration(seconds: recordDuration));
        
        if (!isRecording) break;

        // 3. Stop the current recording
        final file = await controller!.stopVideoRecording();
        
        // 4. Process in background (burn timestamp)
        // We move processing entirely to background to allow loop to continue immediately
        unawaited(_processVideo(file.path, folderPath, startTime));
        
        // Loop immediately continues to start the next recording
      } catch (e) {
        debugPrint("Loop error: $e");
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _processVideo(String tempPath, String folderPath, DateTime startTime) async {
    final String timestampBase = (startTime.millisecondsSinceEpoch / 1000).floor().toString();
    final String newPath = p.join(folderPath, "VID_${DateTime.now().millisecondsSinceEpoch}.mp4");

    debugPrint("FFmpeg processing: $tempPath");

    // FFmpeg command to burn timestamp
    final String command = "-i $tempPath -vf \"drawtext=fontfile=/system/fonts/Roboto-Regular.ttf:text='%{pts\\:localtime\\:$timestampBase}':x=w-tw-20:y=h-th-20:fontsize=32:fontcolor=white:box=1:boxcolor=black@0.5\" -c:v libx264 -preset ultrafast -c:a copy $newPath";

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint("Video processed: $newPath");
      await File(tempPath).delete();
      await platform.invokeMethod('scanFile', {"path": newPath});
      _deleteOldFiles(Directory(folderPath));
    } else {
      debugPrint("FFmpeg failed. Saving raw.");
      final savedPath = p.join(folderPath, "VID_RAW_${DateTime.now().millisecondsSinceEpoch}.mp4");
      await File(tempPath).copy(savedPath);
      await File(tempPath).delete();
      await platform.invokeMethod('scanFile', {"path": savedPath});
    }
  }

  Future<void> _deleteOldFiles(Directory dir) async {
    try {
      const int minFreeSpace = 500 * 1024 * 1024; // 500 MB Buffer

      while (true) {
        // Get current free space from native side
        final int? freeSpace = await platform.invokeMethod<int>('getFreeDiskSpace');
        
        if (freeSpace == null || freeSpace > minFreeSpace) break; // Enough space or error

        final List<FileSystemEntity> entities = dir.listSync();
        final List<File> dashcamFiles = entities
            .whereType<File>()
            .where((file) => p.basename(file.path).startsWith("VID_"))
            .toList();

        if (dashcamFiles.isEmpty) break; // No more files to delete

        // Sort by modification time and delete the oldest one
        dashcamFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        
        final fileToDelete = dashcamFiles.first;
        debugPrint("Deleting oldest file to free space: ${fileToDelete.path}");
        await fileToDelete.delete();
        await platform.invokeMethod('scanFile', {"path": fileToDelete.path});
      }
    } catch (e) {
      debugPrint("Cleanup error: $e");
    }
  }

  Future<void> stopLoopRecording() async {
    if (!isRecording) return;
    
    isRecording = false;
    if (controller != null && controller!.value.isRecordingVideo) {
      final file = await controller!.stopVideoRecording();
      final dir = Directory('/storage/emulated/0/Movies/Dashcam');
      unawaited(_processVideo(file.path, dir.path, DateTime.now().subtract(Duration(seconds: recordDuration))));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    
    // In landscape, we need to handle the camera's natural aspect ratio correctly.
    // The camera plugin often returns aspectRatio as height/width (e.g. 0.56) 
    // even when the screen is in landscape. We ensure we use the landscape ratio (> 1).
    double cameraRatio = controller!.value.aspectRatio;
    if (cameraRatio < 1) cameraRatio = 1 / cameraRatio;
    
    double scale;
    if (deviceRatio < cameraRatio) {
      scale = cameraRatio / deviceRatio;
    } else {
      scale = deviceRatio / cameraRatio;
    }

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

          // 2. Left Side: Settings
          Positioned(
            left: 30,
            top: 0,
            bottom: 0,
            child: Center(
              child: Tooltip(
                message: "Settings",
                triggerMode: TooltipTriggerMode.tap,
                child: GestureDetector(
                  onTap: isRecording ? null : _showSettings,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Top Right: REC Indicator and Clock
          Positioned(
            top: 20,
            right: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.red, size: 14),
                        SizedBox(width: 8),
                        Text(
                          "REC",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  _currentTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),

          // 4. Right Side: Start/Stop Button
          Positioned(
            right: 30,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isRecording)
                    FloatingActionButton.large(
                      heroTag: "start",
                      backgroundColor: Colors.green,
                      onPressed: startLoopRecording,
                      child: const Icon(Icons.play_arrow, size: 40),
                    )
                  else
                    FloatingActionButton.large(
                      heroTag: "stop",
                      backgroundColor: Colors.red,
                      onPressed: stopLoopRecording,
                      child: const Icon(Icons.stop, size: 40),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
