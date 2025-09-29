import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:fitness/pages/profile_user.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class GesturePage extends StatefulWidget {
  const GesturePage({super.key});

  @override
  State<GesturePage> createState() => _GesturePageState();
}

class _GesturePageState extends State<GesturePage> {
  CameraController? controller;
  String gesture = "No gesture detected";
  String expectedPrompt = "";
  bool isProcessing = false;
  bool isDetected = false;
  String? errorMessage;

  // Throttling variables
  DateTime lastProcessTime = DateTime.now();
  static const Duration processingInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    initCamera();
    getNewPrompt();
  }

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          errorMessage = "No cameras available";
        });
        return;
      }

      controller = CameraController(
        cameras.first,
        ResolutionPreset.medium, // Better quality than low
        enableAudio: false,
      );

      await controller!.initialize();

      if (mounted) {
        setState(() {});

        // Start streaming frames with throttling
        controller!.startImageStream((CameraImage image) async {
          final now = DateTime.now();

          // Throttle processing to avoid overwhelming the server
          if (now.difference(lastProcessTime) < processingInterval ||
              isProcessing) {
            return;
          }

          lastProcessTime = now;
          await processFrame(image);
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to initialize camera: $e";
      });
    }
  }

  Future<void> processFrame(CameraImage image) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // Convert CameraImage to JPEG bytes
      final bytes = await convertCameraImageToJpeg(image);

      if (bytes == null) {
        setState(() {
          errorMessage = "Failed to convert image";
          isProcessing = false;
        });
        return;
      }

      // Send to Flask server
      final uri = Uri.parse("https://b28cacd6926a.ngrok-free.app/detect");
      final request = http.MultipartRequest("POST", uri);

      // Add the image file
      request.files.add(
        http.MultipartFile.fromBytes("frame", bytes, filename: "frame.jpg"),
      );

      // Add expected prompt if available
      if (expectedPrompt.isNotEmpty) {
        request.fields['expected_prompt'] = expectedPrompt;
      }

      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseString);

        if (mounted) {
          setState(() {
            if (data['success'] == true && data['result'] != null) {
              final result = data['result'];
              gesture = result['gesture'] ?? 'Unknown';
              isDetected = result['detected'] ?? false;
              if (isDetected) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileUser()),
                );
                return;
              }
              errorMessage = null;
            } else {
              gesture = "Processing error";
              isDetected = false;
              errorMessage = data['error'] ?? 'Unknown error';
            }
            isProcessing = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            gesture = "Server error";
            isDetected = false;
            errorMessage = "Server returned ${response.statusCode}";
            isProcessing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          gesture = "Connection error";
          isDetected = false;
          errorMessage = "Failed to connect: $e";
          isProcessing = false;
        });
      }
    }
  }

  Future<Uint8List?> convertCameraImageToJpeg(CameraImage cameraImage) async {
    try {
      // Handle different image formats
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return convertYUV420ToJpeg(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return convertBGRA8888ToJpeg(cameraImage);
      } else {
        print('Unsupported image format: ${cameraImage.format.group}');
        return null;
      }
    } catch (e) {
      print('Error converting image: $e');
      return null;
    }
  }

  Uint8List? convertYUV420ToJpeg(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      final int yRowStride = cameraImage.planes[0].bytesPerRow;
      final int uvRowStride = cameraImage.planes[1].bytesPerRow;
      final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

      final Uint8List yPlane = cameraImage.planes[0].bytes;
      final Uint8List uPlane = cameraImage.planes[1].bytes;
      final Uint8List vPlane = cameraImage.planes[2].bytes;

      final img.Image image = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * yRowStride + x;
          final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

          final int yValue = yPlane[yIndex];
          final int uValue = uPlane[uvIndex];
          final int vValue = vPlane[uvIndex];

          // YUV to RGB conversion
          final int r = (yValue + 1.370705 * (vValue - 128)).round().clamp(
            0,
            255,
          );
          final int g =
              (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128))
                  .round()
                  .clamp(0, 255);
          final int b = (yValue + 1.732446 * (uValue - 128)).round().clamp(
            0,
            255,
          );

          image.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      print('Error in YUV420 conversion: $e');
      return null;
    }
  }

  Uint8List? convertBGRA8888ToJpeg(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      final Uint8List bytes = cameraImage.planes[0].bytes;

      // Create image manually from BGRA bytes
      final img.Image image = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int index = (y * width + x) * 4;
          if (index + 3 < bytes.length) {
            final int b = bytes[index];
            final int g = bytes[index + 1];
            final int r = bytes[index + 2];
            final int a = bytes[index + 3];

            image.setPixelRgba(x, y, r, g, b, a);
          }
        }
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      print('Error in BGRA8888 conversion: $e');
      return null;
    }
  }

  Future<void> getNewPrompt() async {
    try {
      final response = await http.get(
        Uri.parse("https://9b526e604e83.ngrok-free.app/new_prompt"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          expectedPrompt = data['new_prompt'] ?? '';
          isDetected = false; // Reset detection status
        });
      }
    } catch (e) {
      print('Failed to get new prompt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gesture Detection"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: getNewPrompt,
            tooltip: 'Get New Prompt',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              child: controller != null && controller!.value.isInitialized
                  ? CameraPreview(controller!)
                  : Center(
                      child: errorMessage != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(),
                    ),
            ),
          ),

          // Status and results section
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Current prompt
                  if (expectedPrompt.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Try this gesture:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            expectedPrompt,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Detection result
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDetected ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDetected
                            ? Colors.green[200]!
                            : Colors.orange[200]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isDetected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isDetected ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isDetected ? "Detected!" : "Keep trying...",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDetected
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Current: $gesture",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Processing indicator
                  if (isProcessing)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text("Processing..."),
                      ],
                    ),

                  // Error message
                  if (errorMessage != null && !isProcessing)
                    Text(
                      "Error: $errorMessage",
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: getNewPrompt,
        tooltip: 'New Challenge',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
