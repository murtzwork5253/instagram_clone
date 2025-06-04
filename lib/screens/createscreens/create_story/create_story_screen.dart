import 'dart:math' as math;

import 'package:Instagram/screens/createscreens/create_story/story_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../camera_service.dart';

class CreateStoryContent extends StatefulWidget {
  final CameraService cameraService;
  const CreateStoryContent({Key? key, required this.cameraService}) : super(key: key);

  @override
  State<CreateStoryContent> createState() => _CreateStoryContentState();
}

class _CreateStoryContentState extends State<CreateStoryContent>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {

  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  CameraService get _cameraService => widget.cameraService; // Add this getter

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _toggleCamera() async {
    try {
      await _cameraService.toggleCamera();
      if (mounted) {
        setState(() {});
      }
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.description!)),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await _cameraService.toggleFlash();
      if (mounted) {
        setState(() {});
      }
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.description!)),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    if (!_cameraService.isCameraInitialized || _cameraService.controller == null) return;

    try {
      if (_cameraService.controller!.value.isTakingPicture) {
        return;
      }

      final XFile image = await _cameraService.controller!.takePicture();
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
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white),
                title: const Text('Save to device', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openTextMode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Text Mode...')),
    );
  }

  void _openLayoutMode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Layout Mode...')),
    );
  }

  void _openBoomerangEffects() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Boomerang/Effects...')),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't dispose the camera service here since it's shared
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_cameraService.isCameraInitialized || _cameraService.controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
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
                    if (_cameraService.controller == null || !_cameraService.controller!.value.isInitialized) return;

                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(details.globalPosition);
                    final previewSize = renderBox.size;

                    final offset = Offset(
                      localPosition.dx / previewSize.width,
                      localPosition.dy / previewSize.height,
                    );

                    await _cameraService.setFocusPoint(offset);
                  },
                  onDoubleTap: () async {
                    await _toggleCamera();
                  },
                  onScaleStart: (details) {
                    _baseZoomLevel = _currentZoomLevel;
                  },
                  onScaleUpdate: (details) async {
                    if (_cameraService.controller == null ||
                        !_cameraService.controller!.value.isInitialized ||
                        details.pointerCount != 2) return;

                    double zoom = _baseZoomLevel * details.scale;
                    final minZoom = await _cameraService.getMinZoomLevel();
                    final maxZoom = await _cameraService.getMaxZoomLevel();
                    zoom = zoom.clamp(minZoom, maxZoom);

                    await _cameraService.setZoomLevel(zoom);
                    _currentZoomLevel = zoom;
                  },
                  child: _cameraService.isFrontCamera
                      ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: CameraPreview(_cameraService.controller!),
                  )
                      : CameraPreview(_cameraService.controller!),
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
                    if (!_cameraService.isFrontCamera)
                      IconButton(
                        icon: Icon(
                          _cameraService.isFlashOn ? Icons.flash_on : Icons.flash_off,
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

          // Side controls
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

          // Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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