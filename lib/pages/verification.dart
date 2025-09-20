import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:fitness/auth/auth_service.dart';
import 'package:fitness/pages/profile_user.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class Verification extends StatefulWidget {
  const Verification({super.key});

  @override
  State<Verification> createState() => _VerificationState();
}

class _VerificationState extends State<Verification> {
  // Update this URL or make it configurable
  static const String BASE_URL = "https://b69caf211302.ngrok-free.app";
  // Alternative: Use your actual server IP if running locally
  // static const String BASE_URL = "http://YOUR_IP:5000";

  List<String> prompts = [
    "Wave your hand",
    "Show your index finger",
    "Close your fist",
    "Open your hand",
    "Show peace sign (two fingers)",
  ];

  CameraController? controller;
  bool isProcessing = false;
  String currentPrompt = "";
  String detectionResult = "";
  Random random = Random();
  bool detected = false;
  final authService = AuthService();

  int frameSkipCounter = 0;
  int detectionCount = 0;
  static const int requiredDetections = 3;
  static const int frameSkip = 5;
  bool serverConnected = false;

  @override
  void initState() {
    super.initState();
    _checkServerConnection(); // Test connection first
    _newPrompt();
    _initializeCamera();
  }

  void _newPrompt() {
    setState(() {
      currentPrompt = prompts[random.nextInt(prompts.length)];
      detectionResult = serverConnected ? "Waiting..." : "Server not connected";
      detectionCount = 0;
    });
  }

  // Test all server endpoints to see what's available
  Future<void> _checkServerConnection() async {
    List<String> endpointsToTest = [
      "/",
      "/health",
      "/detect",
      "/test_detector",
      "/new_prompt",
    ];

    setState(() => detectionResult = "Testing server connection...");

    for (String endpoint in endpointsToTest) {
      try {
        print("Testing endpoint: $BASE_URL$endpoint");

        final response = await http
            .get(
              Uri.parse("$BASE_URL$endpoint"),
              headers: {
                "ngrok-skip-browser-warning": "true",
                "User-Agent": "Flutter App",
              },
            )
            .timeout(const Duration(seconds: 10));

        print("$endpoint: ${response.statusCode}");

        if (response.statusCode == 200) {
          print("$endpoint response: ${response.body}");
          serverConnected = true;
          setState(() => detectionResult = "Server connected ✅");
          break;
        }
      } catch (e) {
        print("$endpoint error: $e");
      }
    }

    if (!serverConnected) {
      setState(
        () => detectionResult = "❌ Cannot connect to server. Check URL.",
      );
    }
  }

  // Test POST request to /detect endpoint specifically
  Future<void> _testDetectEndpoint() async {
    try {
      setState(() => detectionResult = "Testing /detect endpoint...");

      // Create a small test image (1x1 white pixel)
      final testImage = img.Image(width: 1, height: 1);
      img.fill(testImage, color: img.ColorRgb8(255, 255, 255));
      final testImageBytes = img.encodeJpg(testImage);
      final testBase64 = base64Encode(testImageBytes);

      final response = await http
          .post(
            Uri.parse("$BASE_URL/detect"),
            headers: {
              "Content-Type": "application/json",
              "ngrok-skip-browser-warning": "true",
              "User-Agent": "Flutter App",
            },
            body: jsonEncode({"image": testBase64}),
          )
          .timeout(const Duration(seconds: 10));

      print("POST /detect status: ${response.statusCode}");
      print("POST /detect response: ${response.body}");

      if (response.statusCode == 200) {
        setState(() => detectionResult = "/detect endpoint working ✅");
        serverConnected = true;
      } else {
        setState(
          () => detectionResult = "/detect failed: ${response.statusCode}",
        );
      }
    } catch (e) {
      setState(() => detectionResult = "/detect error: $e");
      print("Detect endpoint test error: $e");
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.low, // Use low resolution for debugging
        enableAudio: false,
      );

      await controller!.initialize();

      if (!mounted) return;

      setState(() {});

      // Only start image stream if server is connected
      if (serverConnected) {
        controller!.startImageStream((image) async {
          frameSkipCounter++;
          if (frameSkipCounter < frameSkip) return;
          frameSkipCounter = 0;

          if (isProcessing || detected) return;

          isProcessing = true;
          await _sendFrame(image);
          isProcessing = false;
        });
      }
    } catch (e) {
      setState(() => detectionResult = "Camera error: $e");
      print("Camera initialization error: $e");
    }
  }

  Future<void> _sendFrame(CameraImage image) async {
    if (!serverConnected) {
      setState(() => detectionResult = "Server not connected");
      return;
    }

    try {
      final rgbBytes = _convertYUV420ToRGB(image);

      final rgbImage = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: rgbBytes.buffer,
        order: img.ChannelOrder.rgb,
      );

      // Use smaller image for better performance
      final resized = img.copyResize(rgbImage, width: 224, height: 224);
      final jpegBytes = img.encodeJpg(resized, quality: 70);
      final base64Image = base64Encode(jpegBytes);

      print("Sending frame to $BASE_URL/detect");

      final response = await http
          .post(
            Uri.parse("$BASE_URL/detect"),
            headers: {
              "Content-Type": "application/json",
              "ngrok-skip-browser-warning": "true",
              "User-Agent": "Flutter App",
            },
            body: jsonEncode({"image": base64Image}),
          )
          .timeout(const Duration(seconds: 8));

      print("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Response data: $data");

        if (data.containsKey("error")) {
          setState(() => detectionResult = "Server error: ${data["error"]}");
          return;
        }

        final bool gestureDetected = data["detected"] == true;
        final double confidence = (data["confidence"] ?? 0.0).toDouble();
        final int handsFound = data["hands_found"] ?? 0;

        if (gestureDetected) {
          detectionCount++;
          setState(() {
            detectionResult =
                "Detected! ($detectionCount/$requiredDetections) ✅";
          });

          if (detectionCount >= requiredDetections && !detected) {
            detected = true;
            authService.addVerification(detected);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ProfileUser()),
              );
            }
          }
        } else {
          detectionCount = 0;

          if (handsFound == 0) {
            setState(() => detectionResult = "Show your hand 👋");
          } else {
            setState(() => detectionResult = "Try the gesture: $currentPrompt");
          }
        }
      } else if (response.statusCode == 404) {
        setState(() => detectionResult = "❌ /detect endpoint not found");
        serverConnected = false;
      } else {
        setState(
          () => detectionResult = "Server error: ${response.statusCode}",
        );
        print("HTTP Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      setState(() => detectionResult = "Network error: $e");
      print("Frame processing error: $e");
    }
  }

  Uint8List _convertYUV420ToRGB(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final rgb = Uint8List(width * height * 3);

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);

        final yp = yPlane.bytes[y * yPlane.bytesPerRow + x];
        final up = uPlane.bytes[uvIndex];
        final vp = vPlane.bytes[uvIndex];

        int r = (yp + 1.402 * (vp - 128)).round();
        int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
        int b = (yp + 1.772 * (up - 128)).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        final index = (y * width + x) * 3;
        rgb[index] = r;
        rgb[index + 1] = g;
        rgb[index + 2] = b;
      }
    }

    return rgb;
  }

  @override
  void dispose() {
    controller?.stopImageStream();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(detectionResult),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkServerConnection,
                child: const Text("Test Server"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verification Page"),
        backgroundColor: serverConnected ? Colors.green : Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkServerConnection,
            tooltip: "Test Connection",
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Server status indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: serverConnected
                ? Colors.green.shade100
                : Colors.red.shade100,
            child: Text(
              serverConnected
                  ? "🟢 Server Connected"
                  : "🔴 Server Disconnected",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: serverConnected
                    ? Colors.green.shade800
                    : Colors.red.shade800,
              ),
            ),
          ),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AspectRatio(
                  aspectRatio: controller!.value.aspectRatio,
                  child: CameraPreview(controller!),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Perform this gesture:",
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentPrompt,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    detectionResult,
                    style: TextStyle(
                      fontSize: 16,
                      color: detectionResult.contains("✅")
                          ? Colors.green
                          : detectionResult.contains("❌")
                          ? Colors.red
                          : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Control buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _newPrompt,
                      child: const Text("New Prompt"),
                    ),
                    ElevatedButton(
                      onPressed: _checkServerConnection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Test Server"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _testDetectEndpoint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Test /detect Endpoint"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
