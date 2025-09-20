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

  @override
  void initState() {
    super.initState();
    _newPrompt();
    _initializeCamera();
  }

  void _newPrompt() {
    setState(() {
      currentPrompt = prompts[random.nextInt(prompts.length)];
      detectionResult = "Waiting...";
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      // Always pick the front camera
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller!.initialize();

      if (!mounted) return;

      setState(() {});

      // Start image stream
      controller!.startImageStream((image) async {
        if (isProcessing || detected) return;

        isProcessing = true;
        await _sendFrame(image);
        isProcessing = false;
      });
    } catch (e) {
      setState(() => detectionResult = "Camera error: $e");
    }
  }

  Future<void> _sendFrame(CameraImage image) async {
    try {
      final rgbBytes = _convertYUV420ToRGB(image);

      final rgbImage = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: rgbBytes.buffer,
        order: img.ChannelOrder.rgb,
      );

      final resized = img.copyResize(rgbImage, width: 224);

      final jpegBytes = img.encodeJpg(resized, quality: 70);

      final base64Image = base64Encode(jpegBytes);

      final response = await http.post(
        Uri.parse("https://b69caf211302.ngrok-free.app/detect"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"image": base64Image}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool gestureDetected = data["detected"] == true;

        if (gestureDetected && !detected) {
          detected = true;
          authService.addVerification(detected);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfileUser()),
            );
          }
        } else {
          setState(() => detectionResult = "Not detected ❌");
        }
      } else {
        setState(
          () => detectionResult = "Server error: ${response.statusCode}",
        );
      }
    } catch (e) {
      setState(() => detectionResult = "Error: $e");
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
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Verification Page")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: CameraPreview(controller!),
          ),
          const SizedBox(height: 20),
          Text(currentPrompt, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 10),
          Text(detectionResult, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _newPrompt,
            child: const Text("New Prompt"),
          ),
        ],
      ),
    );
  }
}

// Dummy Profile P
