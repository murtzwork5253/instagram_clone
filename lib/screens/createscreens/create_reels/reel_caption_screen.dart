import 'dart:async';
import 'dart:io';
import 'package:Instagram/screens/createscreens/create_reels/tag_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class ReelCaptionScreen extends StatefulWidget {
  final Map<String, dynamic> reelData;

  const ReelCaptionScreen({
    Key? key,
    required this.reelData,
  }) : super(key: key);

  @override
  State<ReelCaptionScreen> createState() => _ReelCaptionScreenState();
}

class _ReelCaptionScreenState extends State<ReelCaptionScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  final TextEditingController _captionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isUploading = false;
  bool _isVideoPlaying = true;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  // User data - you should get this from your auth/user service
  String? _currentUserId;
  String _currentUsername = '';
  String _currentUserAvatar = '';
  String? musicUrl;

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _initializeAnimations();
    _getCurrentUser();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeInOut),
    );
    _fadeAnimationController.forward();
  }

  Future<void> _getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _currentUserId = user.id;

        // Get user profile data
        final response = await _supabase
            .from('users')
            .select('username, profile_image_url')
            .eq('id', user.id)
            .single();

        setState(() {
          _currentUsername = response['username'] ?? 'user_${user.id.substring(0, 8)}';
          _currentUserAvatar = response['profile_image_url'] ?? '';
        });
      }
    } catch (e) {
      print('Error getting current user: $e');
      // Set fallback values
      setState(() {
        _currentUsername = 'Anonymous User';
        _currentUserAvatar = '';
      });
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(File(widget.reelData['videoPath']));
    await _videoController.initialize();
    _videoController.setLooping(true);
    _videoController.play();
    setState(() {});
  }

  void _toggleVideoPlayback() {
    setState(() {
      if (_isVideoPlaying) {
        _videoController.pause();
      } else {
        _videoController.play();
      }
      _isVideoPlaying = !_isVideoPlaying;
    });
  }

  Future<String?> _uploadVideoToSupabase(String videoPath) async {
    try {
      final file = File(videoPath);
      final fileName = 'reel_${DateTime.now().millisecondsSinceEpoch}_${path.basename(videoPath)}';
      final fileBytes = await file.readAsBytes();

      setState(() {
        _uploadStatus = 'Uploading video...';
        _uploadProgress = 0.0;
      });

      // Upload to Supabase Storage
      await _supabase.storage
          .from('reels')
          .uploadBinary(fileName, fileBytes);

      setState(() {
        _uploadProgress = 0.8;
        _uploadStatus = 'Processing...';
      });

      // Get public URL
      final publicUrl = _supabase.storage
          .from('reels')
          .getPublicUrl(fileName);

      setState(() {
        _uploadProgress = 1.0;
        _uploadStatus = 'Upload complete!';
      });

      return publicUrl;
    } catch (e) {
      print('Error uploading video: $e');
      setState(() {
        _uploadStatus = 'Upload failed: ${e.toString()}';
      });
      return null;
    }
  }

  Future<String?> _uploadMusicToSupabase(String? musicPath) async {
    if (musicPath == null || musicPath.isEmpty) return null;

    try {
      final file = File(musicPath);
      if (!await file.exists()) return null;

      final fileName = 'music_${DateTime.now().millisecondsSinceEpoch}_${path.basename(musicPath)}';
      final fileBytes = await file.readAsBytes();

      await _supabase.storage
          .from('music') // Create this bucket in Supabase
          .uploadBinary(fileName, fileBytes);

      return _supabase.storage
          .from('music')
          .getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading music: $e');
      return null;
    }
  }

  Future<void> _saveReelToDatabase(String videoUrl) async {
    print('Trim values before saving: Start=${widget.reelData['musicTrimStart']}, End=${widget.reelData['musicTrimEnd']}');

    try {
      // Handle trim values - they come as ratios (0.0-1.0) from the editor
      double musicTrimStartRatio = 0.0;
      double musicTrimEndRatio = 0.0;

      if (widget.reelData['musicTrimStart'] != null && widget.reelData['musicTrimEnd'] != null) {
        musicTrimStartRatio = (widget.reelData['musicTrimStart'] ?? 0.0).toDouble();
        musicTrimEndRatio = (widget.reelData['musicTrimEnd'] ?? 0.0).toDouble();

        print('Music trim ratios - Start: $musicTrimStartRatio, End: $musicTrimEndRatio');

        // Validate ratios
        if (musicTrimStartRatio < 0.0) musicTrimStartRatio = 0.0;
        if (musicTrimEndRatio > 1.0) musicTrimEndRatio = 1.0;
        if (musicTrimEndRatio <= musicTrimStartRatio) musicTrimEndRatio = 1.0;

        print('Validated trim ratios - Start: $musicTrimStartRatio, End: $musicTrimEndRatio');
      }

      await _supabase.from('reels').insert({
        'video_url': videoUrl,
        'user_id': _currentUserId,
        'username': _currentUsername,
        'user_avatar': _currentUserAvatar,
        'caption': _captionController.text.trim(),
        'music_url': musicUrl,
        'music_trim_start': musicTrimStartRatio, // Store as ratio (0.0-1.0)
        'music_trim_end': musicTrimEndRatio,     // Store as ratio (0.0-1.0)
        'is_video_muted': widget.reelData['isVideoMuted'],
        'text_overlays': widget.reelData['textOverlays'],
        'created_at': DateTime.now().toIso8601String(),
      });

      print('Saved trim values as ratios: Start=$musicTrimStartRatio, End=$musicTrimEndRatio');
    } catch (e) {
      print('Error saving reel to database: $e');
      throw e;
    }
  }

  // Add this method to your _ReelCaptionScreenState class
  Future<String> _processVideoWithOverlays(String videoPath, String caption) async {
    setState(() {
      _uploadStatus = 'Preparing video...';
      _uploadProgress = 0.5;
    });

    // For now, just return the original video path
    // The overlays will be stored in the database and applied on playback
    await Future.delayed(const Duration(seconds: 2)); // Simulate processing

    setState(() {
      _uploadStatus = 'Video ready for upload!';
      _uploadProgress = 1.0;
    });

    return videoPath;
  }

  Future<void> _publishReel() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing upload...';
    });

    try {
      // Process video with overlays before upload
      final processedVideoPath = await _processVideoWithOverlays(
        widget.reelData['videoPath'],
        _captionController.text.trim(),
      );

      // Upload the processed video instead of original
      final videoUrl = await _uploadVideoToSupabase(processedVideoPath);

      if (widget.reelData['musicPath'] != null) {
        setState(() {
          _uploadStatus = 'Uploading music...';
          _uploadProgress = 0.3;
        });
        musicUrl = await _uploadMusicToSupabase(widget.reelData['musicPath']);
      }

      if (videoUrl != null) {
        // Clean up processed video file
        final processedFile = File(processedVideoPath);
        if (await processedFile.exists()) {
          await processedFile.delete();
        }

        // Save reel data to database
        await _saveReelToDatabase(videoUrl);

        // Show success and navigate back
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Reel published successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate back to home or reels feed
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        throw Exception('Failed to upload video');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Failed to publish reel: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Top section with video preview
                Flexible(
                  flex: 3,
                  child: Container(
                    child: Stack(
                      children: [
                        // Video preview
                        Center(
                          child: AspectRatio(
                            aspectRatio: 9 / 16,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GestureDetector(
                                onTap: _toggleVideoPlayback,
                                child: Stack(
                                  children: [
                                    if (_videoController.value.isInitialized)
                                      VideoPlayer(_videoController),

                                    // Play/Pause overlay
                                    if (!_isVideoPlaying)
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Top bar
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 10,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'New Reel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _toggleVideoPlayback,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 24,
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

                // Bottom section with caption and controls
                // NEW CODE - Replace the above section with this:
                Flexible(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: SingleChildScrollView( // <-- Wrap content in SingleChildScrollView
                      child: Padding( // <-- Apply padding here to affect the scrollable area
                        padding: const EdgeInsets.all(20), // Apply padding once here
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Handle bar (keep it here as it's part of the visual header)
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                margin: const EdgeInsets.only(top: 0, bottom: 12), // Adjust margin
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),

                            // User profile section
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: _currentUserAvatar.isNotEmpty
                                        ? (_currentUserAvatar.startsWith('http://') || _currentUserAvatar.startsWith('https://'))
                                        ? NetworkImage(_currentUserAvatar) as ImageProvider<Object>?
                                        : FileImage(File(_currentUserAvatar)) as ImageProvider<Object>?
                                        : null,
                                    child: _currentUserAvatar.isEmpty
                                        ? Icon(Icons.person, color: Colors.grey[600])
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _currentUsername,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'Share to your feed',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // // Caption input
                            // Text(
                            //   'Write a caption...',
                            //   style: TextStyle(
                            //     fontSize: 16,
                            //     fontWeight: FontWeight.w600,
                            //     color: Colors.grey[800],
                            //   ),
                            // ),

                            const SizedBox(height: 12),

                            Container( // Changed from Expanded to Container
                              // constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.15), // Example max height for caption
                              height: 120,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: TextField(
                                controller: _captionController,
                                scrollController: _scrollController,
                                maxLines: 5,
                                expands: false,
                                minLines: 3,
                                textAlignVertical: TextAlignVertical.top,
                                keyboardType: TextInputType.multiline,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Share what\'s on your mind...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // // Quick actions (remove location and music buttons)
                            // Row(
                            //   children: [
                            //     _buildQuickAction(Icons.tag, 'Tag people'),
                            //   ],
                            // ),

                            const SizedBox(height: 24),

                            // Share button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isUploading ? null : _publishReel,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0095F6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isUploading
                                    ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        value: _uploadProgress > 0 ? _uploadProgress : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _uploadStatus,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                                    : const Text(
                                  'Share',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Save as draft button
                            Align( // Use Align to center if needed, or remove for full width
                              alignment: Alignment.center,
                              child: TextButton(
                                onPressed: _isUploading ? null : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Reel saved as draft Coming soon'),
                                      // backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  'Save as draft',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 20 + MediaQuery.of(context).viewInsets.bottom),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Upload progress overlay
            if (_isUploading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Card(
                      margin: EdgeInsets.all(40),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Publishing your reel...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please don\'t close the app',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        // Implement quick action functionality
        if(label=='Tag people'){
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TagUsersScreen(), // This will be your new screen
            ),
          );
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.grey[700],
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController.dispose();
    _captionController.dispose();
    _scrollController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }
}