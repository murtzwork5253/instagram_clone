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
  final bool isActive;
  const CreateStoryContent({Key? key, required this.cameraService,required this.isActive}) : super(key: key);

  @override
  State<CreateStoryContent> createState() => _CreateStoryContentState();
}

class _CreateStoryContentState extends State<CreateStoryContent>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {

  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;
  bool _isGridVisible = false; // Grid visibility state

  CameraService get _cameraService => widget.cameraService;

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
        // Stop camera before navigating to preview
        await _cameraService.stopCamera();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryPreviewScreen(
              imagePath: filePath,
              isFrontCamera: _cameraService.isFrontCamera,
            ),
          ),
        ).then((_) {
          // Restart camera when returning from preview
          _cameraService.restartCamera(enableAudio: false);
        });
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
          // Stop camera before navigating to preview
          await _cameraService.stopCamera();

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StoryPreviewScreen(imagePath: image.path),
            ),
          ).then((_) {
            // Restart camera when returning from preview
            _cameraService.restartCamera(enableAudio: false);
          });
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

  void _toggleGrid() {
    setState(() {
      _isGridVisible = !_isGridVisible;
    });

    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isGridVisible ? 'Grid enabled' : 'Grid disabled'),
        duration: const Duration(milliseconds: 800),
        backgroundColor: Colors.black.withOpacity(0.7),
      ),
    );
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
                onTap: _showPrivacySettings,
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

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Story Privacy', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Everyone', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'everyone',
                groupValue: 'everyone',
                onChanged: (value) {},
                activeColor: Colors.blue,
              ),
            ),
            ListTile(
              title: const Text('Followers only', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'followers',
                groupValue: 'everyone',
                onChanged: (value) {},
                activeColor: Colors.blue,
              ),
            ),
            ListTile(
              title: const Text('Close friends', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'close_friends',
                groupValue: 'everyone',
                onChanged: (value) {},
                activeColor: Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _cameraService,
      builder: (context, child) {
        if (!widget.isActive || !_cameraService.isCameraInitialized || _cameraService.controller == null) {
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
                    child: Stack(
                      children: [
                        // Camera Preview
                        GestureDetector(
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
                            child: (_cameraService.controller != null &&
                                _cameraService.controller!.value.isInitialized &&
                                !_cameraService.isDisposed)
                                ? CameraPreview(_cameraService.controller!)
                                : const Center(child: CircularProgressIndicator()),
                          )
                              : (_cameraService.controller != null &&
                              _cameraService.controller!.value.isInitialized &&
                              !_cameraService.isDisposed)
                              ? CameraPreview(_cameraService.controller!)
                              : const Center(child: CircularProgressIndicator()),
                        ),
                        // Grid Overlay
                        if (_isGridVisible)
                          const GridOverlay(),
                      ],
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

              // Side controls - Grid toggle button
              Positioned(
                right: 10,
                top: MediaQuery.of(context).padding.top + 70,
                child: Column(
                  children: [
                    _buildGridControlIcon(),
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
      },
    );
  }

  Widget _buildGridControlIcon() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: _toggleGrid,
        child: Container(
          decoration: BoxDecoration(
            color: _isGridVisible
                ? Colors.white.withOpacity(0.3)
                : Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
            border: _isGridVisible
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.grid_on,
            color: _isGridVisible ? Colors.white : Colors.white.withOpacity(0.8),
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// Grid Overlay Widget
class GridOverlay extends StatelessWidget {
  const GridOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GridPainter(),
      child: Container(),
    );
  }
}

// Custom Painter for drawing the grid
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Rule of thirds - Draw 2 vertical and 2 horizontal lines
    // Vertical lines
    final double verticalSpacing = size.width / 3;
    for (int i = 1; i < 3; i++) {
      final double x = verticalSpacing * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    final double horizontalSpacing = size.height / 3;
    for (int i = 1; i < 3; i++) {
      final double y = horizontalSpacing * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}