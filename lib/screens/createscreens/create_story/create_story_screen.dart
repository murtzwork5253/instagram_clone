import 'dart:math' as math;

import 'package:Instagram/screens/createscreens/create_story/story_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:image_picker/image_picker.dart'; // For gallery access

// This list should ideally be initialized once in main.dart before runApp
// For demonstration, we'll keep it here, but remember the best practice
// is to fetch availableCameras() at app startup.
List<CameraDescription> cameras = [];

class CreateStoryContent extends StatefulWidget {
  const CreateStoryContent({Key? key}) : super(key: key);

  @override
  State<CreateStoryContent> createState() => _CreateStoryContentState();
}

class _CreateStoryContentState extends State<CreateStoryContent> with WidgetsBindingObserver {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  CameraDescription? _selectedCamera;
  bool _isFlashOn = false;
  bool _isFrontCamera = false; // To track if the current camera is front-facing
  ResolutionPreset _currentResolutionPreset = ResolutionPreset.high; // Current resolution preset

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer for lifecycle events
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed, check if camera needs to be paused/resumed
    if (!_isCameraInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(); // Re-initialize camera if app is resumed
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        cameras = await availableCameras();
      } on CameraException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error accessing cameras: ${e.description}')),
          );
        }
        return;
      }
    }

    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cameras available')),
        );
      }
      return;
    }

    // Dispose previous controller if it exists
    if (_isCameraInitialized && _controller.value.isInitialized) {
      await _controller.dispose();
    }

    // If _selectedCamera is null (first time init), pick the first available camera
    // Otherwise, use the already selected camera.
    // If there's a front camera, prefer it for initial setup if no camera is selected.
    if (_selectedCamera == null) {
      _selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first, // Fallback to first if no back camera
      );
      _isFrontCamera = (_selectedCamera!.lensDirection == CameraLensDirection.front);
    }


    _controller = CameraController(
      _selectedCamera!,
      _currentResolutionPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg, // Recommended for general photo capture
    );

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          // Ensure flash mode is off when initializing new controller or switching cameras
          _isFlashOn = false;
          _controller.setFlashMode(FlashMode.off);
        });
      }
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: ${e.description}')),
        );
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (!_isCameraInitialized || cameras.length < 2) {
      // Cannot toggle if only one or no camera is available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot toggle camera: only one camera found or not initialized.')),
      );
      return;
    }

    final CameraDescription newCamera = (_selectedCamera!.lensDirection == CameraLensDirection.back)
        ? cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front)
        : cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.back);

    if (_controller.value.isInitialized) {
      await _controller.dispose();
    }

    _selectedCamera = newCamera;
    _isFrontCamera = (newCamera.lensDirection == CameraLensDirection.front);

    _controller = CameraController(
      _selectedCamera!,
      _currentResolutionPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isFlashOn = false; // Reset flash state on camera switch
          _controller.setFlashMode(FlashMode.off);
        });
      }
    } on CameraException catch (e) {
      print('Error switching camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error switching camera: ${e.description}')),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized || _isFrontCamera) {
      // Flash is typically not available or useful for front camera
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash not available for front camera or not initialized.')),
      );
      return;
    }

    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.always;
      await _controller.setFlashMode(newFlashMode);
      if (mounted) {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      }
    } on CameraException catch (e) {
      print('Error setting flash: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting flash: ${e.description}')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || !_controller.value.isInitialized) return;

    try {
      // Ensure the camera is ready
      if (_controller.value.isTakingPicture) {
        return; // A capture is already in progress
      }

      final XFile image = await _controller.takePicture();
      final directory = await getTemporaryDirectory();
      final String filePath = path.join(directory.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

      await image.saveTo(filePath);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryPreviewScreen(imagePath: filePath),
          ),
        );
      }
      print('Picture saved to: $filePath');
    } on CameraException catch (e) {
      print('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: ${e.description}')),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Image picked from gallery: ${image.path}')),
          // );
          // Here, you would typically navigate to a preview/editor screen with the picked image
          // For example:
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StoryPreviewScreen(imagePath: image.path),
            ),
          );
        }
        print('Image picked from gallery: ${image.path}');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected from gallery.')),
          );
        }
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _openStorySettings() {
    // This is a placeholder for opening a settings dialog or new screen.
    // You can implement a custom dialog or a new route here.
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Story Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.white),
                title: const Text('Story Privacy', style: TextStyle(color: Colors.white)),
                onTap: () {
                  // Handle privacy settings
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white),
                title: const Text('Save to device', style: TextStyle(color: Colors.white)),
                onTap: () {
                  // Handle save settings
                  Navigator.pop(context);
                },
              ),
              // Add more settings options
            ],
          ),
        );
      },
    );
  }

  void _openTextMode() {
    // Placeholder for text mode.
    // You would typically navigate to a new screen or show an overlay
    // where the user can type text for their story.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Text Mode...')),
    );
  }

  void _openLayoutMode() {
    // Placeholder for layout mode.
    // This could involve choosing collage layouts or grid arrangements.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Layout Mode...')),
    );
  }

  void _openBoomerangEffects() {
    // Placeholder for boomerang/effects.
    // This might involve applying visual effects or recording short looping videos.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Boomerang/Effects...')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }


    // Calculate the camera preview aspect ratio
    final cameraAspectRatio = _controller.value.aspectRatio;
    double _currentZoomLevel = 1.0;
    double _baseZoomLevel = 1.0;

    // Determine if the preview needs to be mirrored for the front camera.
    // We only mirror the preview, not the captured image.
    final Matrix4 transform = Matrix4.identity();
    if (_isFrontCamera) {
      transform.rotateY(cameraAspectRatio * 3.14159265359); // Rotate around Y-axis for mirroring
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  onTapDown: (TapDownDetails details) async {
                    if (!_controller.value.isInitialized) return;

                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(details.globalPosition);
                    final previewSize = renderBox.size;

                    final offset = Offset(
                      localPosition.dx / previewSize.width,
                      localPosition.dy / previewSize.height,
                    );

                    try {
                      await _controller.setFocusPoint(offset);
                      await _controller.setExposurePoint(offset);
                    } catch (e) {
                      debugPrint('Failed to set focus point: $e');
                    }
                  },
                  onDoubleTap: () async{
                    await _toggleCamera();
                  },
                  onScaleStart: (details) {
                    _baseZoomLevel = _currentZoomLevel;
                  },
                  onScaleUpdate: (details) async {
                    if(!_controller.value.isInitialized || details.pointerCount != 2) return;

                    double zoom = (_baseZoomLevel * details.scale).clamp(
                      await _controller.getMinZoomLevel(),
                      await _controller.getMaxZoomLevel(),
                    );

                    try {
                      await _controller.setZoomLevel(zoom);
                      _currentZoomLevel = zoom;
                    } catch (e) {
                      debugPrint('Zoom failed: $e');
                    }
                  },
                  child: _isFrontCamera
                      ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: CameraPreview(_controller),
                  )
                      : CameraPreview(_controller),
                ),
              ),
            ),
          ),

          // Gradient Overlay at the top and bottom for text visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top Row: Close, Flash, Settings/More
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                Row(
                  children: [
                    if (!_isFrontCamera) // Only show flash button if it's the back camera
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _toggleFlash,
                      ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                      onPressed: _openStorySettings,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Side controls (e.g., filters, layouts, boomerangs)
          Positioned(
            right: 10,
            top: MediaQuery.of(context).padding.top + 70,
            child: Column(
              children: [
                _buildStoryControlIcon(Icons.text_fields, _openTextMode),
                _buildStoryControlIcon(Icons.grid_on, _openLayoutMode),
                _buildStoryControlIcon(Icons.gif_box_outlined, _openBoomerangEffects),
              ],
            ),
          ),

          // Bottom Controls: Gallery, Capture, Camera Switch
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Capture Button
                    GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal:8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Gallery Button
                      GestureDetector(
                        onTap: _pickImageFromGallery,
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
                        ),
                      ),
                      // Camera Switch Button
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 35),
                        onPressed: _toggleCamera,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryControlIcon(IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}