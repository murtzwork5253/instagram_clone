import 'dart:async';
import 'dart:io';
import 'package:Instagram/screens/createscreens/create_reels/reel_caption_screen.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

class ReelPreviewScreen extends StatefulWidget {
  final String recordedVideoPath;
  final String? backgroundMusicPath;
  final bool isVideoMuted;

  const ReelPreviewScreen({
    Key? key,
    required this.recordedVideoPath,
    this.backgroundMusicPath,
    this.isVideoMuted = false,
  }) : super(key: key);

  @override
  State<ReelPreviewScreen> createState() => _ReelPreviewScreenState();
}

class _ReelPreviewScreenState extends State<ReelPreviewScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  AudioPlayer? _audioPlayer;
  String? _selectedMusicPath;
  bool _isVideoMuted = false;
  bool _isMusicPlaying = false;
  bool _isVideoPlaying = true;
  bool _showTextEditor = false;
  bool _showMusicSelector = false;
  List<TextOverlay> _textOverlays = [];
  int _selectedOverlayIndex = -1;
  late AnimationController _playPauseAnimationController;
  TextEditingController _textController = TextEditingController();
  bool _isMasterPlaying = false;
  Timer? _masterSyncTimer;

  // Music synchronization properties
  Duration _musicDuration = Duration.zero;
  Duration _videoDuration = Duration.zero;
  Duration _musicStartTime = Duration.zero;
  Duration _currentVideoPosition = Duration.zero;
  double _musicTrimStart = 0.0;
  double _musicTrimEnd = 1.0;
  Timer? _previewTimer;
  Timer? _musicMonitorTimer;
  Duration _currentPreviewPosition = Duration.zero;

  // Text styling options
  Color _selectedTextColor = Colors.white;
  double _selectedTextSize = 24.0;
  FontWeight _selectedFontWeight = FontWeight.normal;
  TextAlign _selectedTextAlign = TextAlign.center;

  final List<Color> _textColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();

    _playPauseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _videoController = VideoPlayerController.file(File(widget.recordedVideoPath));
    _audioPlayer = AudioPlayer();

    // Initialize video first
    _initializeVideo().then((_) {
      _isVideoMuted = widget.isVideoMuted;
      _videoController.setVolume(_isVideoMuted ? 0.0 : 1.0);

      // Initialize background music if provided
      if (widget.backgroundMusicPath != null) {
        _selectedMusicPath = widget.backgroundMusicPath;
        _initializeMusic().then((_) {
          // Start playback
          _videoController.play();
          _isMasterPlaying = true;
          _isVideoPlaying = true;

          if (_isVideoMuted) {
            _startMasterSync();
          }

          setState(() {});
        });
      } else {
        // Start video only
        _videoController.play();
        _isMasterPlaying = true;
        _isVideoPlaying = true;
        setState(() {});
      }
    });
  }

  Future<void> _initializeVideo() async {
    _videoController =
        VideoPlayerController.file(File(widget.recordedVideoPath));
    await _videoController.initialize();
    _videoDuration = _videoController.value.duration;
    _videoController.setLooping(true);
    _videoController.play();
    _videoController.setVolume(_isVideoMuted ? 0.0 : 1.0);

    // Listen to video position changes
    _videoController.addListener(_onVideoPositionChanged);

    setState(() {});
  }

  void _onVideoPositionChanged() {
    if (_videoController.value.isInitialized) {
      _currentVideoPosition = _videoController.value.position;
    }
  }

  Future<void> _syncMusicWithVideo() async {
    if (_audioPlayer == null ||
        !_isMusicPlaying || // Music is not supposed to be playing
        _musicDuration == Duration.zero ||
        _selectedMusicPath == null ||
        !_isVideoMuted ||
        !_videoController.value.isInitialized) return;

    try {
      Duration videoPosition = _videoController.value.position;
      Duration videoDuration = _videoController.value.duration;

      if (videoDuration == Duration.zero) return;

      print('Video Position $videoPosition, Video Duration $videoDuration');
      print('Current Music Position ${await _audioPlayer!.getCurrentPosition()}');

      // Ensure music duration is valid
      if (_musicDuration.inMilliseconds <= 0) {
        print("Sync Error: Music duration is zero or invalid.");
        return;
      }

      double musicFullDurationMs = _musicDuration.inMilliseconds.toDouble();
      double musicStartFraction = _musicTrimStart;
      double musicEndFraction = _musicTrimEnd;

      // Ensure trim start is less than trim end
      if (musicStartFraction >= musicEndFraction) {
        // Allow 0.0 to 1.0 for full track
        if (!(musicStartFraction == 0.0 && musicEndFraction == 1.0)) {
          print("Sync Error: Invalid music trim (start >= end). Start: $musicStartFraction, End: $musicEndFraction");
          // Optionally pause music or handle error
          // await _audioPlayer!.pause();
          // _isMusicPlaying = false;
          // _musicMonitorTimer?.cancel();
          // setState((){});
          return;
        }
      }


      double actualMusicTrimStartMs = musicStartFraction * musicFullDurationMs;
      double actualMusicTrimEndMs = musicEndFraction * musicFullDurationMs;
      double trimmedMusicDurationMs = actualMusicTrimEndMs - actualMusicTrimStartMs;

      if (trimmedMusicDurationMs <= 0) {
        // This case might happen if _musicTrimStart == _musicTrimEnd,
        // except for full track 0.0 to 1.0 of a valid duration.
        if (!(musicStartFraction == 0.0 && musicEndFraction == 1.0 && musicFullDurationMs > 0)) {
          print("Sync Error: Trimmed music duration is zero or negative.");
          return;
        }
        // If it's a full track loop, trimmedMusicDurationMs should be musicFullDurationMs
        if (musicStartFraction == 0.0 && musicEndFraction == 1.0) {
          trimmedMusicDurationMs = musicFullDurationMs;
        } else {
          return; // Invalid trim for non-full track
        }
      }


      double videoProgressMs = videoPosition.inMilliseconds.toDouble();
      // Map video position to the equivalent progress within the trimmed music segment (potentially looping)
      double musicProgressInTrimmedSegment = videoProgressMs % trimmedMusicDurationMs;
      double targetMusicPositionMs = actualMusicTrimStartMs + musicProgressInTrimmedSegment;

      // Ensure target position doesn't exceed the actual music file's duration
      if (targetMusicPositionMs >= musicFullDurationMs) {
        targetMusicPositionMs = musicFullDurationMs - 1; // Stay within bounds
      }
      if (targetMusicPositionMs < 0) {
        targetMusicPositionMs = 0;
      }


      Duration targetMusicPosition = Duration(milliseconds: targetMusicPositionMs.round());
      Duration? currentMusicPosition = await _audioPlayer!.getCurrentPosition();

      if (currentMusicPosition != null) {
        int timeDifferenceMs = (targetMusicPosition.inMilliseconds - currentMusicPosition.inMilliseconds).abs();

        // Sync if difference is significant (e.g., > 350ms to avoid too frequent seeks)
        // Or if current music position is outside the *intended* trimmed play segment
        bool isOutsideCurrentTrimSegment =
            currentMusicPosition.inMilliseconds < actualMusicTrimStartMs ||
                currentMusicPosition.inMilliseconds >= actualMusicTrimEndMs;

        // More precise check: if current music position relative to its trim start,
        // is not aligned with videoProgressMs relative to trimmedMusicDurationMs.
        double currentMusicProgressInTrim = (currentMusicPosition.inMilliseconds - actualMusicTrimStartMs);
        // Normalize currentMusicProgressInTrim if it's outside due to looping by _musicMonitorTimer
        if (currentMusicProgressInTrim < 0 || currentMusicProgressInTrim >= trimmedMusicDurationMs) {
          currentMusicProgressInTrim = currentMusicProgressInTrim % trimmedMusicDurationMs;
          if(currentMusicProgressInTrim < 0) currentMusicProgressInTrim += trimmedMusicDurationMs;
        }

        double expectedMusicProgressInTrim = videoProgressMs % trimmedMusicDurationMs;
        int diffInTrimProgress = (expectedMusicProgressInTrim - currentMusicProgressInTrim).abs().round();


        // If the video has looped, but music is still at the end of its trim, it needs a reset.
        // This is also covered by `isOutsideCurrentTrimSegment` if `_musicMonitorTimer` already looped it back.
        if (diffInTrimProgress > 350 ) { // Increased threshold
          print("Syncing music: VideoPos ${videoPosition.inMilliseconds}ms, TargetMusicPos ${targetMusicPosition.inMilliseconds}ms, CurrentMusicPos ${currentMusicPosition.inMilliseconds}ms, Diff ${diffInTrimProgress}ms");
          await _audioPlayer!.seek(targetMusicPosition);
        }
      }
    } catch (e) {
      print('Error during music sync: $e');
    }
  }

  void _startMasterSync() {
    _masterSyncTimer?.cancel();
    _masterSyncTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_isMasterPlaying &&
          _audioPlayer != null &&
          _selectedMusicPath != null &&
          _isVideoMuted &&
          _isMusicPlaying &&
          _videoController.value.isInitialized && // Ensure video is ready
          _videoController.value.isPlaying) {

        await _syncMusicWithVideo();
      }
    });
  }

  Future<void> _initializeMusic() async {
    if (_selectedMusicPath == null) return;

    try {
      _musicMonitorTimer?.cancel();

      // Re-initialize AudioPlayer instance to ensure a clean state
      _audioPlayer?.dispose(); // Dispose previous instance if any
      _audioPlayer = AudioPlayer();
      // It's good practice to set an ID for the player if you have multiple.
      // _audioPlayer!.setPlayerId("background_music_player");


      await _audioPlayer!.setSource(DeviceFileSource(_selectedMusicPath!));

      Duration? duration = await _audioPlayer!.getDuration();
      if (duration != null && duration.inMilliseconds > 0) {
        _musicDuration = duration;
        if (_videoDuration.inMilliseconds > 0) {
          double videoToMusicRatio = _videoDuration.inMilliseconds / _musicDuration.inMilliseconds;
          if (videoToMusicRatio <= 1.0) { // Video is shorter or equal to music
            _musicTrimStart = 0.0;
            _musicTrimEnd = videoToMusicRatio.clamp(0.05, 1.0); // Ensure trimEnd is slightly > trimStart
          } else { // Video is longer than music, use full music and loop it
            _musicTrimStart = 0.0;
            _musicTrimEnd = 1.0;
          }
        } else { // Default trim if video duration is unknown
          _musicTrimStart = 0.0;
          _musicTrimEnd = (_musicDuration.inMilliseconds > 0) ? (15000 / _musicDuration.inMilliseconds).clamp(0.05, 1.0) : 0.5; // Default to 15s or half
          if(_musicTrimEnd <= _musicTrimStart && _musicDuration.inMilliseconds >0) _musicTrimEnd = (_musicTrimStart + 0.1).clamp(0.05,1.0);

        }
      } else {
        _musicDuration = Duration.zero;
        _musicTrimStart = 0.0;
        _musicTrimEnd = 0.0; // Invalid music, so trim is effectively zero
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Could not load music duration.'), backgroundColor: Colors.red),
          );
        }
        print('Error: Music duration is null or zero.');
      }

      // Set ReleaseMode.loop if you want the audioplayer to handle its own full-track looping.
      // However, for trimmed looping, our _musicMonitorTimer is better.
      // So, ReleaseMode.stop is fine, as our timer will seek and replay.
      _audioPlayer!.setReleaseMode(ReleaseMode.stop);


      // If master is already playing and video is muted, start music immediately
      if (_isMasterPlaying && _isVideoMuted) {
        await _startMusicFromTrimmedPosition(); // This will also setup boundary monitoring
        _isMusicPlaying = true;
      }

      setState(() {});
    } catch (e) {
      print('Error initializing music: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing music: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startMusicFromTrimmedPosition() async {
    if (_audioPlayer == null || _selectedMusicPath == null || _musicDuration.inMilliseconds <= 0) {
      _isMusicPlaying = false; // Can't play if conditions not met
      return;
    }

    // Ensure trim values are logical
    if (_musicTrimStart >= _musicTrimEnd && !(_musicTrimStart == 0.0 && _musicTrimEnd == 1.0)) {
      print("Cannot start music: Invalid trim range. Start: $_musicTrimStart, End: $_musicTrimEnd");
      _isMusicPlaying = false;
      return;
    }


    try {
      // Always start from the calculated trim start position
      Duration startPosition = Duration(
          milliseconds: (_musicTrimStart * _musicDuration.inMilliseconds).round());

      // Pause first to ensure any previous playback stops before seek and play
      await _audioPlayer!.pause();
      await _audioPlayer!.seek(startPosition);
      // For audioplayers, after setSource, play doesn't always need the source again unless it changed
      // or if you want to be explicit after a stop/dispose.
      // If setSource was recent and player is just paused, audioPlayer.resume() might be an option.
      // But play() with source is safer if state is uncertain.
      await _audioPlayer!.play(DeviceFileSource(_selectedMusicPath!));
      _isMusicPlaying = true; // Set state after successful play command

      _setupTrimBoundaryMonitoring(); // Setup looping for the trimmed section
    } catch (e) {
      print('Error starting music from trimmed position: $e');
      _isMusicPlaying = false; // Set to false on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing music: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() {}); // Reflect _isMusicPlaying change
  }

  void _setupTrimBoundaryMonitoring() {
    _musicMonitorTimer?.cancel();
    if (_musicDuration.inMilliseconds <= 0) return; // No duration, no monitoring

    // Calculate trim boundaries in milliseconds
    double musicStartMs = _musicTrimStart * _musicDuration.inMilliseconds;
    double musicEndMs = _musicTrimEnd * _musicDuration.inMilliseconds;

    // Ensure trim is valid (at least some duration)
    // Allow 0.0 to 1.0 for full track looping.
    if (musicEndMs <= musicStartMs && !(_musicTrimStart == 0.0 && _musicTrimEnd == 1.0 && _musicDuration.inMilliseconds > 0)) {
      print("Boundary Monitor: Invalid trim duration. Start: $musicStartMs, End: $musicEndMs. Cancelling monitor.");
      return;
    }
    // For full track (0.0 to 1.0), musicEndMs will be _musicDuration.inMilliseconds
    // and musicStartMs will be 0.

    _musicMonitorTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async { // Faster check
      if (!_isMusicPlaying || _audioPlayer == null || !_audioPlayer!.source.toString().contains(_selectedMusicPath!)) { // also check if source is still valid
        timer.cancel();
        return;
      }

      try {
        Duration? currentPos = await _audioPlayer!.getCurrentPosition();
        if (currentPos != null) {
          double currentMs = currentPos.inMilliseconds.toDouble();

          // If current position is at or beyond the trim end, loop back to trim start
          // Add a small buffer (e.g., 50ms) to prevent premature looping if timer fires slightly late
          if (currentMs >= (musicEndMs - 50) ) { // Check against musicEndMs
            print("Music Monitor: Reached trim end (Current: $currentMs ms, TrimEnd: $musicEndMs ms). Seeking to $musicStartMs ms.");
            await _audioPlayer!.seek(Duration(milliseconds: musicStartMs.round()));
            // If player was paused by sync logic just before loop, ensure it resumes
            // This might not be needed if _isMusicPlaying is managed correctly
            // PlayerState playerState = _audioPlayer!.state;
            // if(playerState == PlayerState.paused && _isMusicPlaying) {
            //    await _audioPlayer!.resume();
            // }

          }
          // Optional: If somehow music is playing *before* trim start, correct it.
          // else if (currentMs < musicStartMs) {
          //   print("Music Monitor: Current position $currentMs ms before trim start $musicStartMs ms. Correcting.");
          //   await _audioPlayer!.seek(Duration(milliseconds: musicStartMs.round()));
          // }

        }
      } catch (e) {
        print('Boundary monitoring error: $e');
        // Consider cancelling timer on specific errors
        // timer.cancel();
      }
    });
  }

  Future<void> _addBackgroundMusic() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        // Stop current music if playing
        if (_audioPlayer != null) {
          await _audioPlayer!.stop();
          await _audioPlayer!.dispose();
        }

        _selectedMusicPath = result.files.single.path;
        await _initializeMusic();

        // Show music selector
        _showMusicSelector = true;

        // When music is added, mute video audio
        _isVideoMuted = true;
        _videoController.setVolume(0.0);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Music added: ${result.files.single.name}'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding music: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleVideoAudio() {
    setState(() {
      _isVideoMuted = !_isVideoMuted;
      _videoController.setVolume(_isVideoMuted ? 0.0 : 1.0);

      if (!_isVideoMuted) { // Video audio ON, music OFF
        if (_isMusicPlaying && _audioPlayer != null) {
          _audioPlayer!.pause(); // Use pause instead of stop if you want to resume later from same spot
        }
        _musicMonitorTimer?.cancel();
        _masterSyncTimer?.cancel(); // Stop master sync if video audio is on
        _isMusicPlaying = false;
      } else { // Video audio OFF (muted), music ON (if selected and master is playing)
        if (_selectedMusicPath != null && _isMasterPlaying && _musicDuration.inMilliseconds > 0) {
          // Restart timers for music
          _musicMonitorTimer?.cancel();
          _masterSyncTimer?.cancel();

          _startMusicFromTrimmedPosition().then((_) { // Ensure _isMusicPlaying is updated after attempt
            if(_isMusicPlaying) _startMasterSync(); // Only start sync if music started
            if(mounted) setState(() {});
          });
        } else {
          _isMusicPlaying = false; // Cannot play music
        }
      }
    });
  }

  void _toggleMusicPlayback() async {
    if (_audioPlayer == null || _selectedMusicPath == null) return;

    // Don't allow music toggle if video is unmuted
    if (!_isVideoMuted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mute video audio first to play music'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isMusicPlaying) {
      await _audioPlayer!.pause();
      _musicMonitorTimer?.cancel();
      _isMusicPlaying = false;
    } else {
      await _startMusicFromTrimmedPosition();
      _isMusicPlaying = true;
    }
    setState(() {});
  }

  void _togglePlayback() async {
    if (_isMasterPlaying) { // PAUSE action
      await _videoController.pause();
      if (_audioPlayer != null && _isMusicPlaying) {
        await _audioPlayer!.pause();
      }
      _masterSyncTimer?.cancel();
      _musicMonitorTimer?.cancel();
      _isMasterPlaying = false;
      _isVideoPlaying = false;
      _isMusicPlaying = false; // Music is definitely paused now
    } else { // PLAY action
      await _videoController.play();
      // Check for video errors after attempting to play
      if (_videoController.value.hasError) {
        print("Video Player Error: ${_videoController.value.errorDescription}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Video error: ${_videoController.value.errorDescription}"), backgroundColor: Colors.red),
        );
        _isMasterPlaying = false; // Ensure we don't think we are playing
        _isVideoPlaying = false;
        setState(() {});
        return;
      }
      _isVideoPlaying = true;


      if (_isVideoMuted && _selectedMusicPath != null && _audioPlayer != null && _musicDuration.inMilliseconds > 0) {
        // Ensure music player is ready and timers are reset for a clean start
        _musicMonitorTimer?.cancel(); // Cancel any old monitor
        _masterSyncTimer?.cancel();   // Cancel any old sync timer

        // _isMusicPlaying = false; // Set to false before starting, so _startMusic... can set it true
        // await _audioPlayer!.pause(); // Ensure paused before seek/play

        await _startMusicFromTrimmedPosition(); // This will seek to trim start, play, and setup boundary monitor
        // _isMusicPlaying is set inside _startMusicFromTrimmedPosition

        if (_isMusicPlaying) { // Only start master sync if music actually started playing
          _startMasterSync(); // Start master sync for video-music alignment
        }
      }
      _isMasterPlaying = true;
    }
    setState(() {});
  }

  void _showTextEditor1() {
    setState(() {
      _showTextEditor = true;
      _textController.clear();
      _selectedOverlayIndex = -1;
    });
  }

  void _addTextOverlay() {
    if (_textController.text.isNotEmpty) {
      final overlay = TextOverlay(
        text: _textController.text,
        position: const Offset(0.5, 0.5),
        // Center of screen
        color: _selectedTextColor,
        fontSize: _selectedTextSize,
        fontWeight: _selectedFontWeight,
        textAlign: _selectedTextAlign,
      );

      setState(() {
        _textOverlays.add(overlay);
        _showTextEditor = false;
        _textController.clear();
      });
    }
  }

  void _editTextOverlay(int index) {
    final overlay = _textOverlays[index];
    _textController.text = overlay.text;
    _selectedTextColor = overlay.color;
    _selectedTextSize = overlay.fontSize;
    _selectedFontWeight = overlay.fontWeight;
    _selectedTextAlign = overlay.textAlign;
    _selectedOverlayIndex = index;

    setState(() {
      _showTextEditor = true;
    });
  }

  void _updateTextOverlay() {
    if (_selectedOverlayIndex >= 0 && _textController.text.isNotEmpty) {
      setState(() {
        _textOverlays[_selectedOverlayIndex] = TextOverlay(
          text: _textController.text,
          position: _textOverlays[_selectedOverlayIndex].position,
          color: _selectedTextColor,
          fontSize: _selectedTextSize,
          fontWeight: _selectedFontWeight,
          textAlign: _selectedTextAlign,
        );
        _showTextEditor = false;
        _selectedOverlayIndex = -1;
        _textController.clear();
      });
    }
  }

  void _updateTextPosition(int index, Offset newPosition) {
    setState(() {
      _textOverlays[index] = TextOverlay(
        text: _textOverlays[index].text,
        position: newPosition,
        color: _textOverlays[index].color,
        fontSize: _textOverlays[index].fontSize,
        fontWeight: _textOverlays[index].fontWeight,
        textAlign: _textOverlays[index].textAlign,
      );
    });
  }

  void _deleteTextOverlay(int index) {
    setState(() {
      _textOverlays.removeAt(index);
    });
  }

  void _proceedToCaption() {
    // Here you would navigate to the caption screen with all the data
    // including video path, selected music with trim positions, and text overlays

    Map<String, dynamic> reelData = {
      'videoPath': widget.recordedVideoPath,
      'musicPath': _selectedMusicPath,
      'musicTrimStart': _musicTrimStart,
      'musicTrimEnd': _musicTrimEnd,
      'musicDuration':
          _musicDuration.inMilliseconds, // Add music duration in milliseconds
      'isVideoMuted': _isVideoMuted,
      'textOverlays': _textOverlays
          .map((overlay) => {
                'text': overlay.text,
                'position': {
                  'x': overlay.position.dx,
                  'y': overlay.position.dy
                },
                'color': overlay.color.toARGB32(),
                'fontSize': overlay.fontSize,
                'fontWeight': overlay.fontWeight.index,
                'textAlign': overlay.textAlign.index,
              })
          .toList(),
    };

    print('Proceeding with reel data: $reelData');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelCaptionScreen(reelData: reelData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Player
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  onTap: _togglePlayback,
                  child: Stack(
                    children: [
                      if (_videoController.value.isInitialized)
                        VideoPlayer(_videoController),
                      // Drag target MUST be on top for dragging to work
                      DragTarget<int>(
                        onAcceptWithDetails: (details) {
                          final RenderBox? renderBox =
                              context.findRenderObject() as RenderBox?;
                          if (renderBox != null) {
                            final localPosition =
                                renderBox.globalToLocal(details.offset);
                            final screenSize = MediaQuery.of(context).size;
                            // Get actual video player dimensions
                            final aspectRatio = 9 / 16;
                            final maxWidth = screenSize.width;
                            final maxHeight = screenSize.height;
                            double videoWidth, videoHeight;
                            if (maxWidth / maxHeight > aspectRatio) {
                              videoHeight = maxHeight;
                              videoWidth = videoHeight * aspectRatio;
                            } else {
                              videoWidth = maxWidth;
                              videoHeight = videoWidth / aspectRatio;
                            }
                            final videoLeft = (maxWidth - videoWidth) / 2;
                            final videoTop = (maxHeight - videoHeight) / 2;
                            // Convert to relative position (0.0 to 1.0)
                            final relativeX =
                                (localPosition.dx - videoLeft) / videoWidth;
                            final relativeY =
                                (localPosition.dy - videoTop) / videoHeight;
                            final clampedPosition = Offset(
                              relativeX.clamp(0.0, 1.0),
                              relativeY.clamp(0.0, 1.0),
                            );
                            _updateTextPosition(details.data, clampedPosition);
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.transparent,
                          );
                        },
                      ),
                      // Draggable Text Overlays
                      ..._textOverlays.asMap().entries.map((entry) {
                        int index = entry.key;
                        TextOverlay overlay = entry.value;
                        // Get the video player's actual size and position
                        final screenWidth = MediaQuery.of(context).size.width;
                        final screenHeight = MediaQuery.of(context).size.height;
                        final aspectRatio = 9 / 16;
                        final videoWidth =
                            screenWidth * 0.9; // Assuming some padding
                        final videoHeight = videoWidth / aspectRatio;

                        return Positioned(
                          left: (overlay.position.dx * videoWidth) -
                              25, // Center the text
                          top: (overlay.position.dy * videoHeight) - 12.5,
                          child: Draggable<int>(
                            data: index,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Text(
                                overlay.text,
                                style: TextStyle(
                                  color: overlay.color,
                                  fontSize: overlay.fontSize,
                                  fontWeight: overlay.fontWeight,
                                ),
                                textAlign: overlay.textAlign,
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: Text(
                                overlay.text,
                                style: TextStyle(
                                  color: overlay.color,
                                  fontSize: overlay.fontSize,
                                  fontWeight: overlay.fontWeight,
                                ),
                                textAlign: overlay.textAlign,
                              ),
                            ),
                            child: GestureDetector(
                              onTap: () => _editTextOverlay(index),
                              onLongPress: () => _deleteTextOverlay(index),
                              child: Text(
                                overlay.text,
                                style: TextStyle(
                                  color: overlay.color,
                                  fontSize: overlay.fontSize,
                                  fontWeight: overlay.fontWeight,
                                ),
                                textAlign: overlay.textAlign,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      // Play/Pause Overlay
                      if (!_isVideoPlaying)
                        Center(
                          child: AnimatedBuilder(
                            animation: _playPauseAnimationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 0.8 +
                                    (_playPauseAnimationController.value * 0.1),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(230),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Top Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _togglePlayback,
                ),
              ],
            ),
          ),
          // Side Controls
          Positioned(
            right: 15,
            top: MediaQuery.of(context).size.height * 0.3,
            child: Column(
              children: [
                _buildSideControl(
                  Icons.music_note,
                  'Music',
                  _addBackgroundMusic,
                  isActive: _selectedMusicPath != null,
                ),
                const SizedBox(height: 20),
                if (_selectedMusicPath != null)
                  _buildSideControl(
                    Icons.tune,
                    'Trim',
                    () => setState(() => _showMusicSelector = true),
                    isActive: _showMusicSelector,
                  ),
                const SizedBox(height: 20),
                _buildSideControl(
                  _isVideoMuted ? Icons.volume_off : Icons.volume_up,
                  'Audio',
                  _toggleVideoAudio,
                  isActive: !_isVideoMuted,
                ),
                const SizedBox(height: 20),
                if (_selectedMusicPath != null)
                  _buildSideControl(
                    _isMusicPlaying ? Icons.music_note : Icons.music_off,
                    'Music',
                    _toggleMusicPlayback,
                    isActive: _isMusicPlaying,
                  ),
                const SizedBox(height: 20),
                _buildSideControl(
                  Icons.text_fields,
                  'Text',
                  () => _showTextEditor1(),
                  isActive: _textOverlays.isNotEmpty,
                ),
              ],
            ),
          ),
          // Bottom Controls
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Save as Draft
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reel saved as draft'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text(
                    'Save Draft',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                // Next Button
                ElevatedButton(
                  onPressed: _proceedToCaption,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Music Selector Overlay
          if (_showMusicSelector && _selectedMusicPath != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(230),
                child: Column(
                  children: [
                    // Top bar
                    Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 10,
                        left: 20,
                        right: 20,
                        bottom: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showMusicSelector = false),
                            child: Icon(Icons.close, color: Colors.white, size: 28),
                          ),
                          Text(
                            'Trim Music',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              // The _musicTrimStart and _musicTrimEnd are already updated by the UI.
                              // If the main player was actively playing music, we need to make sure it adjusts
                              // to the new trim smoothly.
                              if (_isMasterPlaying && _isVideoMuted && _isMusicPlaying && _audioPlayer != null && _selectedMusicPath != null && _musicDuration.inMilliseconds > 0) {
                                // Music was playing, and video is muted.
                                // We need to restart the music with the new trim and ensure it syncs.
                                print("Music Trim UI Done: Master was playing. Re-evaluating music with new trim.");

                                await _audioPlayer!.pause(); // Pause current playback
                                _musicMonitorTimer?.cancel();   // Stop old monitor
                                // _masterSyncTimer is controlled by _isMasterPlaying, so it should continue if master is playing.

                                // Restart music from the beginning of the new trim.
                                // _syncMusicWithVideo will then align it with the video's current position.
                                await _startMusicFromTrimmedPosition(); // This sets up new _musicMonitorTimer

                                // If _startMusicFromTrimmedPosition failed, _isMusicPlaying will be false.
                                // _masterSyncTimer (if running) will call _syncMusicWithVideo, which will use the new trim values.
                                // An immediate sync might be beneficial if video is already playing.
                                if (_isMusicPlaying && _videoController.value.isPlaying) {
                                  await _syncMusicWithVideo();
                                }

                              } else {
                                print("Music Trim UI Done: Master was not playing music, or conditions not met. New trim values will apply on next play.");
                              }

                              // Hide the music selector UI
                              setState(() {
                                _showMusicSelector = false;
                              });
                            },
                            child: Text(
                              'Done',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Music waveform visualization
                            Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                children: [
                                  // Waveform bars
                                  Row(
                                    children: List.generate(50, (index) {
                                      double height = 20 + (index % 4) * 15;
                                      double position = index / 50;
                                      bool isInSelection = position >= _musicTrimStart &&
                                          position <= _musicTrimEnd;
                                      return Expanded(
                                        child: Container(
                                          margin: EdgeInsets.symmetric(horizontal: 1),
                                          height: height,
                                          decoration: BoxDecoration(
                                            color: isInSelection ? Colors.blue : Colors.grey[600],
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),

                                  // Selection overlay with handles
                                  Positioned.fill(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        double totalWidth = constraints.maxWidth;
                                        double startX = _musicTrimStart * totalWidth;
                                        double endX = _musicTrimEnd * totalWidth;
                                        double selectionWidth = endX - startX;

                                        return Stack(
                                          children: [
                                            // Left dimmed area
                                            Positioned(
                                              left: 0,
                                              top: 0,
                                              bottom: 0,
                                              width: startX,
                                              child: Container(color: Colors.black.withAlpha(153)),
                                            ),

                                            // Right dimmed area
                                            Positioned(
                                              left: endX,
                                              top: 0,
                                              bottom: 0,
                                              right: 0,
                                              child: Container(color: Colors.black.withAlpha(153)),
                                            ),

                                            // Selection area with borders
                                            Positioned(
                                              left: startX,
                                              top: 0,
                                              bottom: 0,
                                              width: selectionWidth,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  border: Border.symmetric(
                                                    vertical: BorderSide(color: Colors.blue, width: 3),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Left handle
                                            Positioned(
                                              left: startX - 15,
                                              top: 0,
                                              bottom: 0,
                                              child: GestureDetector(
                                                onPanUpdate: (details) {
                                                  double newStart = (details.globalPosition.dx - 20) / totalWidth;
                                                  newStart = newStart.clamp(0.0, _musicTrimEnd - 0.05);
                                                  setState(() {
                                                    _musicTrimStart = newStart;
                                                  });
                                                },
                                                child: Container(
                                                  width: 30,
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Icon(Icons.drag_handle, color: Colors.white, size: 16),
                                                ),
                                              ),
                                            ),

                                            // Right handle
                                            Positioned(
                                              left: endX - 15,
                                              top: 0,
                                              bottom: 0,
                                              child: GestureDetector(
                                                onPanUpdate: (details) {
                                                  double newEnd = (details.globalPosition.dx - 20) / totalWidth;
                                                  newEnd = newEnd.clamp(_musicTrimStart + 0.05, 1.0);
                                                  setState(() {
                                                    _musicTrimEnd = newEnd;
                                                  });
                                                },
                                                child: Container(
                                                  width: 30,
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Icon(Icons.drag_handle, color: Colors.white, size: 16),
                                                ),
                                              ),
                                            ),

                                            // Progress indicator
                                            if (_isMusicPlaying)
                                              StreamBuilder<Duration>(
                                                stream: _audioPlayer?.onPositionChanged,
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData) {
                                                    Duration currentPos = snapshot.data!;
                                                    double currentRatio = currentPos.inMilliseconds /
                                                        _musicDuration.inMilliseconds;

                                                    if (currentRatio >= _musicTrimStart &&
                                                        currentRatio <= _musicTrimEnd) {
                                                      double progressX = currentRatio * totalWidth;
                                                      return Positioned(
                                                        left: progressX - 1,
                                                        top: 0,
                                                        bottom: 0,
                                                        width: 2,
                                                        child: Container(color: Colors.white),
                                                      );
                                                    }
                                                  }
                                                  return SizedBox.shrink();
                                                },
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 30),

                            // Time indicators
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(Duration(
                                      milliseconds: (_musicTrimStart * _musicDuration.inMilliseconds).round())),
                                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Selected: ${_formatDuration(Duration(milliseconds: ((_musicTrimEnd - _musicTrimStart) * _musicDuration.inMilliseconds).round()))}',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  _formatDuration(Duration(
                                      milliseconds: (_musicTrimEnd * _musicDuration.inMilliseconds).round())),
                                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),

                            SizedBox(height: 40),

                            // Quick select buttons
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  Text(
                                    'Quick Select',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 15),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildQuickSelectButton('Video Length', () {
                                        double videoToMusicRatio = _videoDuration.inMilliseconds /
                                            _musicDuration.inMilliseconds;
                                        setState(() {
                                          _musicTrimStart = 0.0;
                                          _musicTrimEnd = videoToMusicRatio.clamp(0.1, 1.0);
                                        });
                                      }),
                                      _buildQuickSelectButton('15s', () {
                                        double fifteenSecRatio = 15000 / _musicDuration.inMilliseconds;
                                        setState(() {
                                          _musicTrimStart = 0.0;
                                          _musicTrimEnd = fifteenSecRatio.clamp(0.1, 1.0);
                                        });
                                      }),
                                      _buildQuickSelectButton('30s', () {
                                        double thirtySecRatio = 30000 / _musicDuration.inMilliseconds;
                                        setState(() {
                                          _musicTrimStart = 0.0;
                                          _musicTrimEnd = thirtySecRatio.clamp(0.1, 1.0);
                                        });
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 40),

                            // Preview button
                            Container(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (_isMusicPlaying) {
                                    await _audioPlayer!.pause();
                                    _videoController.pause();
                                    _isMusicPlaying = false;
                                    _isVideoPlaying = false;
                                  } else {
                                    // Start video from beginning
                                    await _videoController.seekTo(Duration.zero);
                                    _videoController.play();

                                    // Start music from trimmed position
                                    await _startMusicFromTrimmedPosition();
                                    _isMusicPlaying = true;
                                    _isVideoPlaying = true;

                                    // Auto-stop after trimmed duration
                                    Duration trimmedDuration = Duration(
                                        milliseconds: ((_musicTrimEnd - _musicTrimStart) *
                                            _musicDuration.inMilliseconds).round());

                                    Timer(trimmedDuration, () async {
                                      if (_isMusicPlaying && mounted) {
                                        await _audioPlayer!.pause();
                                        _videoController.pause();
                                        setState(() {
                                          _isMusicPlaying = false;
                                          _isVideoPlaying = false;
                                        });
                                      }
                                    });
                                  }
                                  setState(() {});
                                },
                                icon: Icon(_isMusicPlaying ? Icons.pause : Icons.play_arrow),
                                label: Text(_isMusicPlaying ? 'Pause Preview' : 'Preview Selection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Text Editor Overlay
          if (_showTextEditor)
            Positioned.fill(
              child: Scaffold(
                backgroundColor: Colors.black.withAlpha(230),
                resizeToAvoidBottomInset: true, // This handles keyboard
                body: Column(
                  children: [
                    // Top bar
                    Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 10,
                        left: 20,
                        right: 20,
                        bottom: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              FocusScope.of(context)
                                  .unfocus(); // Dismiss keyboard
                              setState(() {
                                _showTextEditor = false;
                                _selectedOverlayIndex = -1;
                                _textController.clear();
                              });
                            },
                            child: Text(
                              'Cancel',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          Text(
                            _selectedOverlayIndex >= 0
                                ? 'Edit Text'
                                : 'Add Text',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              FocusScope.of(context)
                                  .unfocus(); // Dismiss keyboard first
                              if (_selectedOverlayIndex >= 0) {
                                _updateTextOverlay();
                              } else {
                                _addTextOverlay();
                              }
                            },
                            child: Text(
                              'Done',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: MediaQuery.of(context).viewInsets.bottom +
                              20, // Handle keyboard
                        ),
                        child: Column(
                          children: [
                            SizedBox(height: 20),

                            // Text input with live preview
                            Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                minHeight: 120,
                                maxHeight: 200,
                              ),
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(
                                    color: Colors.grey[600]!, width: 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _textController,
                                style: TextStyle(
                                  color: _selectedTextColor,
                                  fontSize: _selectedTextSize,
                                  fontWeight: _selectedFontWeight,
                                ),
                                textAlign: _selectedTextAlign,
                                decoration: InputDecoration(
                                  hintText: 'Add text...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: _selectedTextSize,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                maxLines: null,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                autofocus: true,
                              ),
                            ),

                            SizedBox(height: 30),

                            // Tools section
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Color palette with proper wrapping
                                  Text(
                                    'Colors',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 15),

                                  // Color grid with proper layout
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _textColors.map((color) {
                                      bool isSelected =
                                          _selectedTextColor == color;
                                      return GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedTextColor = color),
                                        child: Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.transparent,
                                              width: 3,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.white
                                                          .withValues(
                                                              red: 255,
                                                              green: 255,
                                                              blue: 255,
                                                              alpha: 0.3),
                                                      blurRadius: 8,
                                                      spreadRadius: 2,
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          child: isSelected
                                              ? Icon(
                                                  Icons.check,
                                                  color: color == Colors.white
                                                      ? Colors.black
                                                      : Colors.white,
                                                  size: 20,
                                                )
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),

                                  SizedBox(height: 30),

                                  // Font size control
                                  Row(
                                    children: [
                                      Icon(Icons.format_size,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Size: ${_selectedTextSize.round()}',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14),
                                            ),
                                            SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                activeTrackColor: Colors.blue,
                                                inactiveTrackColor:
                                                    Colors.grey[700],
                                                thumbColor: Colors.blue,
                                                overlayColor:
                                                    Colors.blue.withAlpha(51),
                                              ),
                                              child: Slider(
                                                value: _selectedTextSize,
                                                min: 12,
                                                max: 48,
                                                divisions: 18,
                                                onChanged: (value) => setState(
                                                    () => _selectedTextSize =
                                                        value),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 20),

                                  // Text alignment controls
                                  Text(
                                    'Alignment',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildAlignmentButton(
                                          Icons.format_align_left,
                                          TextAlign.left),
                                      _buildAlignmentButton(
                                          Icons.format_align_center,
                                          TextAlign.center),
                                      _buildAlignmentButton(
                                          Icons.format_align_right,
                                          TextAlign.right),
                                    ],
                                  ),

                                  SizedBox(height: 20),

                                  // Font weight controls
                                  Text(
                                    'Style',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildFontWeightButton(
                                          'Normal', FontWeight.normal),
                                      _buildFontWeightButton(
                                          'Bold', FontWeight.bold),
                                      _buildFontWeightButton(
                                          'Light', FontWeight.w300),
                                    ],
                                  ),

                                  SizedBox(height: 20),
                                ],
                              ),
                            ),

                            SizedBox(height: 100), // Extra space for keyboard
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildQuickSelectButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSideControl(IconData icon, String label, VoidCallback onTap,
      {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.blue.withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );}

  // Add these helper methods in your class:
  Widget _buildAlignmentButton(IconData icon, TextAlign alignment) {
    bool isSelected = _selectedTextAlign == alignment;
    return GestureDetector(
      onTap: () => setState(() => _selectedTextAlign = alignment),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildFontWeightButton(String label, FontWeight weight) {
    bool isSelected = _selectedFontWeight == weight;
    return GestureDetector(
      onTap: () => setState(() => _selectedFontWeight = weight),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: weight,
          ),
        ),
      ),
    );
  }

  // Update the dispose method to ensure proper cleanup
  @override
  void dispose() {
    _masterSyncTimer?.cancel();
    _musicMonitorTimer?.cancel();
    _previewTimer?.cancel(); // Ensure this is also cancelled

    _videoController.removeListener(_onVideoPositionChanged);
    _videoController.dispose();

    _audioPlayer?.dispose(); // Ensure it's disposed

    _playPauseAnimationController.dispose();
    _textController.dispose();

    super.dispose();
  }
}

class TextOverlay {
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  TextOverlay({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    required this.textAlign,
  });
}