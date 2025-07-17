import 'dart:math' as math;

import 'package:Instagram/screens/createscreens/create_reels/reel_preview_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import '../camera_service.dart';

class CreateReelContent extends StatefulWidget {
  final CameraService cameraService;
  const CreateReelContent({Key? key, required this.cameraService}) : super(key: key);

  @override
  State<CreateReelContent> createState() => _CreateReelContentState();
}

class _CreateReelContentState extends State<CreateReelContent> with WidgetsBindingObserver {
  CameraService get _cameraService => widget.cameraService; // Add this getter
  bool _isRecording = false;
  VideoPlayerController? _videoPlayerController;
  String? _recordedVideoPath;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;
  bool _isMuted = false;
  // Add these fields to _CreateReelContentState:
  AudioPlayer? _audioPlayer;
  String? _selectedAudioPath;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }


  Future<void> _toggleCamera() async {
    if (_isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot switch camera while recording.')),
      );
      return;
    }

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

  Future<void> _startVideoRecording() async {
    if (!_cameraService.isCameraInitialized ||
        _cameraService.controller == null ||
        !_cameraService.controller!.value.isInitialized ||
        _isRecording) return;

    try {
      final directory = await getTemporaryDirectory();
      final String filePath = path.join(directory.path, '${DateTime.now().millisecondsSinceEpoch}.mp4');

      // Start background music if available
      if (_selectedAudioPath != null && !_isMuted) {
        await _playBackgroundMusic();
      }

      await _cameraService.controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordedVideoPath = filePath;
      });
    } on CameraException catch (e) {
      print('Error starting video recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: ${e.description}')),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_cameraService.isCameraInitialized ||
        _cameraService.controller == null ||
        !_cameraService.controller!.value.isRecordingVideo) return;

    try {
      await _stopBackgroundMusic();

      final XFile file = await _cameraService.controller!.stopVideoRecording();
      await file.saveTo(_recordedVideoPath!);
      setState(() {
        _isRecording = false;
      });

      // Stop camera before navigating to preview
      await _cameraService.stopCamera();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelPreviewScreen(
            recordedVideoPath: _recordedVideoPath!,
            backgroundMusicPath: _selectedAudioPath,
          ),
        ),
      ).then((_) {
        // Restart camera when returning from preview
        _cameraService.restartCamera(enableAudio: true);
      });
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: ${e.description}')),
        );
      }
    }
  }

  // NEW CODE - Replace the above section with this:
  Future<void> _pickVideoFromGallery() async {
    final XFile? file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compressing video...'),
          duration: Duration(seconds: 5),
        ),
      );

      final MediaInfo? compressedVideo = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (compressedVideo != null && compressedVideo.path != null) {
        // Stop camera before navigating to preview
        await _cameraService.stopCamera();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReelPreviewScreen(recordedVideoPath: compressedVideo.path!),
          ),
        ).then((_) {
          // Restart camera when returning from preview
          _cameraService.restartCamera(enableAudio: true);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to compress video.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Replace the placeholder method:
  void _openReelSettings() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reel Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.music_note, color: Colors.white),
                title: const Text('Add Music', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _addBackgroundMusic();
                },
              ),
              ListTile(
                leading: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                title: Text(_isMuted ? 'Unmute' : 'Mute', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleMute();
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.white),
                title: const Text('Privacy', style: TextStyle(color: Colors.white)),
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

// Add these new methods:
  Future<void> _addBackgroundMusic() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        _selectedAudioPath = result.files.single.path;
        _audioPlayer = AudioPlayer();

        await _audioPlayer!.setSource(DeviceFileSource(_selectedAudioPath!));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Music added: ${result.files.single.name}')),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding music: $e')),
        );
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_audioPlayer != null) {
      _audioPlayer!.setVolume(_isMuted ? 0.0 : 1.0);
    }
  }

  Future<void> _playBackgroundMusic() async {
    if (_audioPlayer != null && _selectedAudioPath != null && !_isMuted) {
      try {
        await _audioPlayer!.resume();
        setState(() {
          _isPlayingAudio = true;
        });
      } catch (e) {
        print('Error playing audio: $e');
      }
    }
  }

  Future<void> _stopBackgroundMusic() async {
    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.pause();
        setState(() {
          _isPlayingAudio = false;
        });
      } catch (e) {
        print('Error stopping audio: $e');
      }
    }
  }

  void _openEffects() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Effects...')),
    );
  }

  void _openSpeedControl() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Speed Control...')),
    );
  }

  void _openLayoutControl() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Layout Control...')),
    );
  }

  Future<void> _handleTapToFocus(TapDownDetails details) async {
    if (_cameraService.controller == null || !_cameraService.controller!.value.isInitialized) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final previewSize = renderBox.size;

    final offset = Offset(
      localPosition.dx / previewSize.width,
      localPosition.dy / previewSize.height,
    );

    await _cameraService.setFocusPoint(offset);
  }

  Future<void> _handleZoom(ScaleUpdateDetails details) async {
    if (_cameraService.controller == null ||
        !_cameraService.controller!.value.isInitialized ||
        details.pointerCount != 2) return;

    final minZoom = await _cameraService.getMinZoomLevel();
    final maxZoom = await _cameraService.getMaxZoomLevel();

    double zoom = (_baseZoomLevel * details.scale).clamp(minZoom, maxZoom);
    await _cameraService.setZoomLevel(zoom);
    _currentZoomLevel = zoom;
  }

  @override
  Widget build(BuildContext context) {
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
                    child: _recordedVideoPath != null &&
                        _videoPlayerController != null &&
                        _videoPlayerController!.value.isInitialized
                        ? VideoPlayer(_videoPlayerController!)
                        : GestureDetector(
                      onTapDown: _handleTapToFocus,
                      onDoubleTap: _toggleCamera,
                      onScaleStart: (details) {
                        _baseZoomLevel = _currentZoomLevel;
                      },
                      onScaleUpdate: _handleZoom,
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
                          onPressed: _openReelSettings,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Side controls (e.g., effects, speed, layout)
              Positioned(
                right: 10,
                top: MediaQuery.of(context).padding.top + 70,
                child: Column(
                  children: [
                    _buildReelControlIcon(Icons.auto_awesome, _openEffects),
                    _buildReelControlIcon(Icons.speed, _openSpeedControl),
                    _buildReelControlIcon(Icons.grid_on, _openLayoutControl),
                    // In the side controls Column, add:
                    if (_selectedAudioPath != null)
                      _buildReelControlIcon(
                        _isPlayingAudio ? Icons.music_note : Icons.music_off,
                            () => _isPlayingAudio ? _stopBackgroundMusic() : _playBackgroundMusic(),
                      ),
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
                          onTap: _isRecording ? _stopVideoRecording : _startVideoRecording,
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
                                decoration: BoxDecoration(
                                  color: _isRecording ? Colors.red : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: _isRecording
                                    ? const Icon(Icons.stop, color: Colors.white, size: 40)
                                    : null,
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
                          // Gallery Button
                          GestureDetector(
                            onTap: _pickVideoFromGallery,
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: const Icon(Icons.video_library_outlined, color: Colors.white, size: 28),
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
      },
    );
  }

  Widget _buildReelControlIcon(IconData icon, VoidCallback onPressed) {
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
    _videoPlayerController?.dispose();
    _audioPlayer?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}