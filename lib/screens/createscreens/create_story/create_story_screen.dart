import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:Instagram/screens/createscreens/create_story/story_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
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
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin, TickerProviderStateMixin {

  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;
  bool _isGridVisible = false; // Grid visibility state
  Offset? _tapPosition;
  bool _isPortraitModeEnabled = false;
  bool _isFocusing = false;
  bool _focusLocked = false;
  AnimationController? _focusAnimationController;
  Animation<double>? _focusAnimation;
  bool _showZoomSlider = true;
  double _currentBrightness = 0.0; // Exposure compensation value (-1.0 to 1.0)
  bool _showBrightnessSlider = false;


  CameraService get _cameraService => widget.cameraService;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize focus animation controller
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _focusAnimation = Tween<double>(
      begin: 1.2,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _focusAnimationController!,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _toggleCamera() async {
    try {
      _resetFocusOnMovement();
      await _cameraService.toggleCamera();
      if (mounted) {
        setState(() {});
        await _initializeBrightness();
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
        ).then((_) async {
          // Restart camera when returning from preview
          await _cameraService.restartCamera(enableAudio: false);

          await _initializeBrightness();
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
          ).then((_) async {
            // Restart camera when returning from preview
            await _cameraService.restartCamera(enableAudio: false);

            await _initializeBrightness();
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

  Future<void> _handleFocusTap(TapDownDetails details) async {
    if (_cameraService.controller == null || !_cameraService.controller!.value.isInitialized) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPoint = renderBox.globalToLocal(details.globalPosition);
    final Size size = renderBox.size;

    final double x = localPoint.dx / size.width;
    final double y = localPoint.dy / size.height;

    if (x >= 0.0 && x <= 1.0 && y >= 0.0 && y <= 1.0) {
      setState(() {
        _tapPosition = details.globalPosition;
        _isFocusing = true;
        _focusLocked = false;
        _showBrightnessSlider = true; // Show brightness slider
      });

      // Start focus animation
      _focusAnimationController?.reset();
      _focusAnimationController?.forward();

      try {
        await _cameraService.controller!.setFocusPoint(Offset(x, y));
        await _cameraService.controller!.setExposurePoint(Offset(x, y));

        // Simulate focus completion delay
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() {
            _isFocusing = false;
            _focusLocked = true;
          });

          // Show locked focus indicator briefly
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              setState(() {
                _focusLocked = false;
              });
            }
          });

          // Hide focus indicator and brightness slider after 4 seconds
          Future.delayed(const Duration(milliseconds: 4000), () {
            if (mounted) {
              setState(() {
                _tapPosition = null;
                _showBrightnessSlider = false;
              });
            }
          });
        }

        // Haptic feedback
        HapticFeedback.lightImpact();

      } catch (e) {
        print("Focus error: $e");
        if (mounted) {
          setState(() {
            _isFocusing = false;
            _tapPosition = null;
            _showBrightnessSlider = false;
          });
        }
      }
    }
  }

  Future<void> _setFocusPoint(Offset point) async {
    if (!_cameraService.isCameraInitialized || _cameraService.controller == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final double x = point.dx / screenWidth;
    final double y = point.dy / screenHeight;

    try {
      await _cameraService.controller!.setFocusPoint(Offset(x, y));
      await _cameraService.controller!.setExposurePoint(Offset(x, y));

      if (mounted) {
        setState(() {
          _tapPosition = point;
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _tapPosition = null);
        });
      }
    } catch (e) {
      print("Failed to set focus point: $e");
    }
  }

  void _togglePortraitMode() {
    if (!mounted) return;
    setState(() => _isPortraitModeEnabled = !_isPortraitModeEnabled);

    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isPortraitModeEnabled ? 'Portrait mode enabled' : 'Portrait mode disabled'),
        duration: const Duration(milliseconds: 800),
        backgroundColor: Colors.black.withOpacity(0.7),
      ),
    );
  }

  void _resetFocusOnMovement() {
    if (_tapPosition != null && mounted) {
      setState(() {
        _tapPosition = null;
        _isFocusing = false;
        _focusLocked = false;
        _showBrightnessSlider = false;
      });
    }
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
                          onTapDown: _handleFocusTap,
                          onDoubleTap: () async {
                            await _toggleCamera();
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

                        if (_isPortraitModeEnabled)
                          IgnorePointer(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    stops: const [0.2, 1.0],
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        if (_tapPosition != null)
                          Positioned(
                            top: _tapPosition!.dy - 40,
                            left: _tapPosition!.dx - 40,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Focus Square
                                AnimatedBuilder(
                                  animation: _focusAnimation!,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _focusAnimation!.value,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _focusLocked
                                                ? Colors.green
                                                : _isFocusing
                                                ? Colors.yellow
                                                : Colors.white,
                                            width: _focusLocked ? 3 : 2,
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Stack(
                                          children: [
                                            // Corner brackets for better visual feedback
                                            ...List.generate(4, (index) {
                                              return Positioned(
                                                top: index < 2 ? 0 : null,
                                                bottom: index >= 2 ? 0 : null,
                                                left: index % 2 == 0 ? 0 : null,
                                                right: index % 2 == 1 ? 0 : null,
                                                child: Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      top: index < 2 ? BorderSide(
                                                        color: _focusLocked ? Colors.green : Colors.white,
                                                        width: 2,
                                                      ) : BorderSide.none,
                                                      bottom: index >= 2 ? BorderSide(
                                                        color: _focusLocked ? Colors.green : Colors.white,
                                                        width: 2,
                                                      ) : BorderSide.none,
                                                      left: index % 2 == 0 ? BorderSide(
                                                        color: _focusLocked ? Colors.green : Colors.white,
                                                        width: 2,
                                                      ) : BorderSide.none,
                                                      right: index % 2 == 1 ? BorderSide(
                                                        color: _focusLocked ? Colors.green : Colors.white,
                                                        width: 2,
                                                      ) : BorderSide.none,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),

                                            // Center dot for locked focus
                                            if (_focusLocked)
                                              Center(
                                                child: Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: const BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Brightness Slider (appears beside focus square)
                                if (_showBrightnessSlider) ...[
                                  const SizedBox(width: 16),
                                  _buildBrightnessSlider(),
                                ],
                              ],
                            ),
                          ),
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
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 20,
                right: 20,
                child: _buildZoomSlider(),
              ),

              Positioned(
                right: 10,
                top: MediaQuery.of(context).padding.top + 70,
                child: Column(
                  children: [
                    _buildGridControlIcon(),
                    const SizedBox(height: 16),
                    _buildPortraitControlIcon(),
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

  Widget _buildPortraitControlIcon() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: _togglePortraitMode,
        child: Container(
          decoration: BoxDecoration(
            color: _isPortraitModeEnabled
                ? Colors.white.withOpacity(0.3)
                : Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
            border: _isPortraitModeEnabled
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.portrait,
            color: _isPortraitModeEnabled ? Colors.white : Colors.white.withOpacity(0.8),
            size: 24,
          ),
        ),
      ),
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

  Widget _buildZoomSlider() {
    return FutureBuilder<List<double>>(
      future: Future.wait([
        _cameraService.getMinZoomLevel(),
        _cameraService.getMaxZoomLevel(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final minZoom = snapshot.data![0];
        final maxZoom = snapshot.data![1];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.zoom_out, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _currentZoomLevel.clamp(minZoom, maxZoom),
                    min: minZoom,
                    max: maxZoom,
                    onChanged: (value) async {
                      await _cameraService.setZoomLevel(value);
                      setState(() {
                        _currentZoomLevel = value;
                      });

                      // Reset focus when zoom changes significantly
                      _resetFocusOnMovement();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.zoom_in, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_currentZoomLevel.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrightnessSlider() {
    return Container(
      height: 120,
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.brightness_high,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3, // Rotate slider to be vertical
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  trackHeight: 2,
                ),
                child: Slider(
                  value: _currentBrightness,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (value) async {
                    try {
                      await _cameraService.controller!.setExposureOffset(value);
                      setState(() {
                        _currentBrightness = value;
                      });

                      // Provide haptic feedback
                      HapticFeedback.selectionClick();
                    } catch (e) {
                      print("Error setting brightness: $e");
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Icon(
            Icons.brightness_low,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }

// Add this method to initialize brightness value when camera starts:
  Future<void> _initializeBrightness() async {
    if (_cameraService.controller != null &&
        _cameraService.controller!.value.isInitialized &&
        !_cameraService.isDisposed) {
      try {
        // Reset to default brightness
        _currentBrightness = 0.0;
        await _cameraService.controller!.setExposureOffset(_currentBrightness);

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        print("Error initializing brightness: $e");
        // Fallback: just set the UI value without camera call
        if (mounted) {
          setState(() {
            _currentBrightness = 0.0;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusAnimationController?.dispose();
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