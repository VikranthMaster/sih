import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

class Pushup extends StatefulWidget {
  const Pushup({super.key});

  @override
  State<Pushup> createState() => _PushupState();
}

class _PushupState extends State<Pushup> with WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> _submitVideo() async {
    if (_videoPath == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Step 1: Upload video to Supabase storage
      final videoUrl = await _uploadVideoToSupabase(_videoPath!);

      if (videoUrl == null) {
        throw Exception('Failed to get video URL after upload');
      }

      setState(() {
        _uploadedVideoUrl = videoUrl;
      });

      // Step 2: Analyze the video
      await _analyzeVideoFromUrl(videoUrl);

      setState(() {
        _isSubmitting = false;
      });

      _showResultDialog();
    } catch (e) {
      setState(() {
        _error = 'Failed to process video: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _uploadVideo() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        // Validate file size (50MB limit for Supabase)
        final fileSize = await file.length();
        if (fileSize > 50 * 1024 * 1024) {
          throw Exception('File size exceeds 50MB limit');
        }

        // Step 1: Upload to Supabase storage
        final videoUrl = await _uploadVideoToSupabase(
          result.files.single.path!,
        );

        if (videoUrl == null) {
          throw Exception('Failed to get video URL after upload');
        }

        setState(() {
          _uploadedVideoUrl = videoUrl;
        });

        // Step 2: Analyze the video
        await _analyzeVideoFromUrl(videoUrl);

        setState(() {
          _isUploading = false;
        });

        _showResultDialog();
      } else {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to process uploaded video: $e';
        _isUploading = false;
      });
    }
  }

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _videoPath;
  String? _error;
  int? _pushupCount;
  bool _hasRecorded = false;
  bool _isUploading = false;
  String? _uploadedVideoUrl;

  final supabase = Supabase.instance.client;

  Future<void> updatePush(int? pushup) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      print("No User logged in");
      return;
    }
    try {
      final response = await supabase
          .from('profiles')
          .update({'pushups': pushup})
          .eq('id', user.id)
          .select()
          .single();
      print('Pushups updated successfully!');
      print('Updated row: $response');
    } catch (e) {
      print('Error updating pushups: $e');
    }
  }

  // Replace with your actual server URL for analysis
  static const String ANALYSIS_SERVER_URL =
      'https://fc2f45216c4e.ngrok-free.app'; // Update this!

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController?.value.isInitialized != true) return;

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use front camera if available, otherwise use the first camera
      CameraDescription selectedCamera = _cameras!.first;
      for (var camera in _cameras!) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize camera: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController?.value.isInitialized != true) return;

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _error = null;
        _pushupCount = null;
        _hasRecorded = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController?.value.isRecordingVideo != true) return;

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoPath = videoFile.path;
        _hasRecorded = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to stop recording: $e';
        _isRecording = false;
      });
    }
  }

  String _generateVideoFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000);
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    return 'pushup_${userId}_${timestamp}_$random.mp4';
  }

  Future<String?> _uploadVideoToSupabase(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        throw Exception('Video file not found');
      }

      // Generate unique filename
      final fileName = _generateVideoFileName();

      // Upload to Supabase storage
      await _supabase.storage.from('videos').upload(fileName, file);

      // Get public URL
      final publicUrl = _supabase.storage.from('videos').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload video to storage: $e');
    }
  }

  Future<void> _analyzeVideoFromUrl(String videoUrl) async {
    try {
      // Send video URL to analysis server (no need to download and re-upload)
      final response = await http.post(
        Uri.parse('$ANALYSIS_SERVER_URL/pushups'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'video_url': videoUrl}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          int pushupsCount;

          if (data['count'] is int) {
            pushupsCount = data['count'];
          } else if (data['count'] is String) {
            pushupsCount = int.tryParse(data['count']) ?? 0;
          } else {
            pushupsCount = 0; // default fallback
          }

          // Update Supabase
          await updatePush(pushupsCount);
          setState(() {
            _pushupCount = data['count'] ?? 0;
          });

          // Save result to user profile or exercise history
          await _saveExerciseResult(_pushupCount!, videoUrl);
        } else {
          throw Exception(data['error'] ?? 'Analysis failed');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error'] ?? 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Analysis failed: $e');
    }
  }

  Future<void> _saveExerciseResult(int pushupCount, String videoUrl) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Save to exercise history table (create this table if needed)
        await _supabase.from('exercise_history').insert({
          'user_id': user.id,
          'exercise_type': 'pushups',
          'count': pushupCount,
          'video_url': videoUrl,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Update user's total score (if you have a scoring system)
        final currentProfile = await _supabase
            .from('profiles')
            .select('score')
            .eq('id', user.id)
            .single();

        final currentScore = currentProfile['score'] ?? 0;
        final newScore =
            currentScore + pushupCount; // Add pushup count to score

        await _supabase
            .from('profiles')
            .update({'score': newScore})
            .eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Failed to save exercise result: $e');
      // Don't throw error here as the main functionality succeeded
    }
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.fitness_center, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Push-up Results',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade100, Colors.orange.shade200],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Text(
                      'You completed',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_pushupCount',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    Text(
                      _pushupCount == 1 ? 'Push-up' : 'Push-ups',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      color: Colors.green.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Video saved to your workout history',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_pushupCount! > 0) ...[
                Text(
                  'Great job! Keep up the good work! 💪',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  'No push-ups detected. Try again with better form! 🏋️',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetSession();
              },
              child: const Text('Try Again'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to home page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _resetSession() {
    setState(() {
      _videoPath = null;
      _hasRecorded = false;
      _pushupCount = null;
      _error = null;
      _isSubmitting = false;
      _isUploading = false;
      _uploadedVideoUrl = null;
    });
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() => _isLoading = true);

    try {
      // Find the other camera
      final currentLensDirection = _cameraController!.description.lensDirection;
      CameraDescription newCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection != currentLensDirection,
        orElse: () => _cameras!.first,
      );

      await _cameraController!.dispose();

      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to switch camera: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        title: const Text(
          'Push-up Counter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_cameras != null && _cameras!.length > 1 && !_isRecording)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: _switchCamera,
            ),
          // Upload video button for testing
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _isUploading || _isSubmitting ? null : _uploadVideo,
            tooltip: 'Upload Video for Testing',
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade100, Colors.orange.shade200],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                const SizedBox(height: 8),
                Text(
                  'Position yourself in front of the camera and perform push-ups',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Or tap the upload icon to test with a video file',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Camera Preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildCameraPreview(),
              ),
            ),
          ),

          // Status and Controls
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Status Indicator
                if (_isRecording) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Recording...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ] else if (_hasRecorded) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Recording Complete',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ] else if (_isUploading) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Uploading and Analyzing...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // Error Message
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Control Buttons
                Row(
                  children: [
                    // Start/Stop Recording Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading || _isSubmitting || _isUploading
                            ? null
                            : (_isRecording ? _stopRecording : _startRecording),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording
                              ? Colors.red
                              : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isRecording ? Icons.stop : Icons.videocam),
                            const SizedBox(width: 8),
                            Text(
                              _isRecording
                                  ? 'Stop Recording'
                                  : 'Start Recording',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_hasRecorded) ...[
                      const SizedBox(width: 12),

                      // Submit Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || _isUploading)
                              ? null
                              : _submitVideo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Analyzing...'),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send),
                                    SizedBox(width: 8),
                                    Text(
                                      'Submit',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Upload Video Button for Testing
                if (!_isRecording && !_hasRecorded && !_isUploading) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading || _isSubmitting
                          ? null
                          : _uploadVideo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: const Text(
                        'Upload Video for Testing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _cameraController?.value.isInitialized != true) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Camera not available',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),

        // Recording overlay
        if (_isRecording)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 4),
            ),
          ),
      ],
    );
  }
}
