import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraService extends ChangeNotifier {
  // Remove singleton pattern: no static _instance, no factory
  CameraController? _controller;
  bool _isCameraInitialized = false;
  CameraDescription? _selectedCamera;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  ResolutionPreset _currentResolutionPreset = ResolutionPreset.high;
  List<CameraDescription> _cameras = [];
  bool _enableAudio = false;
  bool _isDisposed = false; // Add this flag

  // Getters
  CameraController? get controller => _controller;
  bool get isCameraInitialized => _isCameraInitialized && !_isDisposed;
  bool get isFlashOn => _isFlashOn;
  bool get isFrontCamera => _isFrontCamera;
  List<CameraDescription> get cameras => _cameras;
  bool get isDisposed => _isDisposed;

  Future<void> initializeCameras() async {
    if (_cameras.isEmpty) {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        _cameras = await availableCameras();
      } on CameraException catch (e) {
        debugPrint('Error accessing cameras: ${e.description}');
        rethrow;
      }
    }
  }

  Future<void> initializeCamera({bool enableAudio = false}) async {
    if (_isDisposed) return;

    _enableAudio = enableAudio;

    if (_cameras.isEmpty) {
      await initializeCameras();
    }

    if (_cameras.isEmpty) {
      throw CameraException('No cameras available', 'No cameras found on device');
    }

    if (_controller != null) {
      if (_controller!.enableAudio != enableAudio && _controller!.value.isInitialized) {
        await _controller!.dispose();
        _controller = null;
        _isCameraInitialized = false;
        notifyListeners();
      } else if (_controller!.value.isInitialized) {
        return;
      }
    }

    if (_controller == null) {
      if (_selectedCamera == null) {
        _selectedCamera = _cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );
        _isFrontCamera = (_selectedCamera!.lensDirection == CameraLensDirection.front);
      }

      _controller = CameraController(
        _selectedCamera!,
        _currentResolutionPreset,
        enableAudio: enableAudio,
        // KEY CHANGE: Use yuv420 for better Android compatibility
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      try {
        await _controller!.initialize();
        _isCameraInitialized = true;
        _isFlashOn = false;
        _isDisposed = false;
        await _controller!.setFlashMode(FlashMode.off);
        notifyListeners();
      } on CameraException catch (e) {
        debugPrint('Error initializing camera: $e');
        _isCameraInitialized = false;
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> toggleCamera() async {
    if (!_isCameraInitialized || _cameras.length < 2 || _isDisposed) {
      throw CameraException('Cannot toggle camera', 'Only one camera found or not initialized');
    }

    if (_controller != null && _controller!.value.isRecordingVideo) {
      throw CameraException('Cannot switch camera', 'Cannot switch camera while recording');
    }

    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.dispose();
      _controller = null;
      _isCameraInitialized = false;
      notifyListeners();
    }

    final CameraDescription newCamera = (_selectedCamera!.lensDirection == CameraLensDirection.back)
        ? _cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front)
        : _cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.back);

    _selectedCamera = newCamera;
    _isFrontCamera = (newCamera.lensDirection == CameraLensDirection.front);

    _controller = CameraController(
      _selectedCamera!,
      _currentResolutionPreset,
      enableAudio: _enableAudio,
      // KEY CHANGE: Use yuv420 for better Android compatibility
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      _isCameraInitialized = true;
      _isFlashOn = false;
      await _controller!.setFlashMode(FlashMode.off);
      notifyListeners();
    } on CameraException catch (e) {
      debugPrint('Error switching camera: $e');
      _isCameraInitialized = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleFlash() async {
    if (!_isCameraInitialized || _isFrontCamera || _controller == null || _isDisposed) {
      throw CameraException('Flash not available', 'Flash not available for front camera or not initialized');
    }

    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.always;
      await _controller!.setFlashMode(newFlashMode);
      _isFlashOn = !_isFlashOn;
      notifyListeners();
    } on CameraException catch (e) {
      debugPrint('Error setting flash: $e');
      rethrow;
    }
  }

  Future<void> setFocusPoint(Offset offset) async {
    if (_controller != null && _controller!.value.isInitialized && !_isDisposed) {
      try {
        await _controller!.setFocusPoint(offset);
        await _controller!.setExposurePoint(offset);
      } catch (e) {
        debugPrint('Failed to set focus point: $e');
      }
    }
  }

  Future<void> setZoomLevel(double zoom) async {
    if (_controller != null && _controller!.value.isInitialized && !_isDisposed) {
      try {
        final minZoom = await _controller!.getMinZoomLevel();
        final maxZoom = await _controller!.getMaxZoomLevel();
        final clampedZoom = zoom.clamp(minZoom, maxZoom);
        await _controller!.setZoomLevel(clampedZoom);
      } catch (e) {
        debugPrint('Zoom failed: $e');
      }
    }
  }

  Future<double> getMinZoomLevel() async {
    if (_controller != null && _controller!.value.isInitialized && !_isDisposed) {
      return await _controller!.getMinZoomLevel();
    }
    return 1.0;
  }

  Future<double> getMaxZoomLevel() async {
    if (_controller != null && _controller!.value.isInitialized && !_isDisposed) {
      return await _controller!.getMaxZoomLevel();
    }
    return 1.0;
  }

  // New method to properly dispose camera when leaving creation screens
  Future<void> stopCamera() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }
    _isCameraInitialized = false;
    _isDisposed = true;
    notifyListeners();
  }

  // New method to restart camera when returning to creation screens
  Future<void> restartCamera({bool enableAudio = false}) async {
    _isDisposed = false;
    await initializeCamera(enableAudio: enableAudio);
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.dispose();
      _controller = null;
    }
    _isCameraInitialized = false;
    _isDisposed = true;

    // Only call super.dispose() if this is the final disposal
    if (hasListeners) {
      super.dispose();
    }
  }
}