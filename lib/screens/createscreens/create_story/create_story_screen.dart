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
        // Stop camera before navigating to preview
        await _cameraService.stopCamera();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryPreviewScreen(
              imagePath: filePath,
              isFrontCamera: _cameraService.isFrontCamera, // Pass front camera info
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
                groupValue: 'everyone', // Make this stateful
                onChanged: (value) {},
                activeColor: Colors.blue,
              ),
            ),
            ListTile(
              title: const Text('Followers only', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'followers',
                groupValue: 'everyone', // Make this stateful
                onChanged: (value) {},
                activeColor: Colors.blue,
              ),
            ),
            ListTile(
              title: const Text('Close friends', style: TextStyle(color: Colors.white)),
              leading: Radio<String>(
                value: 'close_friends',
                groupValue: 'everyone', // Make this stateful
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

  void _showTimerSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Story Duration', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('3 seconds', style: TextStyle(color: Colors.white)),
              leading: Radio<int>(
                value: 3,
                groupValue: 24, // Make this stateful
                onChanged: (value) {},
                activeColor: Colors.blue,
              ),
            ),
            ListTile(
              title: const Text('10 seconds', style: TextStyle(color: Colors.white)),
              leading: Radio<int>(
                value: 10,
                groupValue: 24, // Make this stateful
                onChanged: (value) {},
                activeColor: Colors.blue,
              ),
            ),
            ListTile(
              title: const Text('24 hours (default)', style: TextStyle(color: Colors.white)),
              leading: Radio<int>(
                value: 24,
                groupValue: 24, // Make this stateful
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

  void _openTextMode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Add Text',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildTextStyleOption('Classic', Colors.white, Colors.transparent),
                    _buildTextStyleOption('Modern', Colors.black, Colors.white),
                    _buildTextStyleOption('Neon', Colors.cyan, Colors.black),
                    _buildTextStyleOption('Gradient', Colors.purple, Colors.pink),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextStyleOption(String name, Color textColor, Color backgroundColor) {
    return ListTile(
      title: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Text(
          'Sample Text',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
      subtitle: Text(name, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        // Implement text overlay functionality
      },
    );
  }

  void _openLayoutMode() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Layout Options',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              children: [
                _buildLayoutOption('Single', Icons.crop_portrait),
                _buildLayoutOption('Collage', Icons.grid_on),
                _buildLayoutOption('Split', Icons.vertical_split),
                _buildLayoutOption('Frame', Icons.border_all),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutOption(String name, IconData icon) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name layout selected')),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _openBoomerangEffects() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Effects & Filters',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildEffectOption('Boomerang', Icons.repeat, Colors.purple),
                  _buildEffectOption('Superzoom', Icons.zoom_in, Colors.blue),
                  _buildEffectOption('Rewind', Icons.replay, Colors.green),
                  _buildEffectOption('Slow Mo', Icons.slow_motion_video, Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Filters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterOption('Normal', Colors.grey),
                  _buildFilterOption('Vintage', Colors.brown),
                  _buildFilterOption('Bright', Colors.yellow),
                  _buildFilterOption('Dramatic', Colors.red),
                  _buildFilterOption('Cool', Colors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectOption(String name, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name effect applied')),
        );
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 4),
            Text(name, style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String name, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name filter applied')),
        );
      },
      child: Container(
        width: 60,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color),
        ),
        child: Center(
          child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
        listenable: _cameraService,
        builder: (context, child) {
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
                          child: (_cameraService.controller != null &&
                              _cameraService.controller!.value.isInitialized &&
                              !_cameraService.isDisposed)
                              ? CameraPreview(_cameraService.controller!)
                              : Center(child: CircularProgressIndicator()),
                        )
                            : (_cameraService.controller != null &&
                            _cameraService.controller!.value.isInitialized &&
                            !_cameraService.isDisposed)
                            ? CameraPreview(_cameraService.controller!)
                            : Center(child: CircularProgressIndicator()),
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
          },
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't dispose the camera service here since it's shared
    super.dispose();
  }
}