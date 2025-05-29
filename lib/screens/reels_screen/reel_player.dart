import 'package:Instagram/screens/commentscreen/comment_section.dart';
import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';
import 'package:Instagram/screens/reels_screen/reel_modal.dart';

class ReelPlayer extends StatefulWidget {
  final Reel reel;// Redundant if PageView handles it

  const ReelPlayer({
    Key? key,
    required this.reel,
  }) : super(key: key);

  @override
  _ReelPlayerState createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool isLiked = false; // Local state, should be managed by Provider

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.reel.videoUrl);
    _videoController.initialize().then((_) {
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: false, // Set to true for auto-play on visibility
        looping: true,
        showControls: false,
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_videoController.value.isInitialized) { // Ensure controller is initialized
      if (info.visibleFraction > 0.5 && !_videoController.value.isPlaying) {
        _videoController.play();
      } else if (info.visibleFraction <= 0.5 && _videoController.value.isPlaying) {
        _videoController.pause();
        _videoController.seekTo(Duration.zero); // Reset to start when off-screen
      }
    }
  }

  void _handleDoubleTapLike() {
    // This is a local UI animation.
    // The actual like logic should go through the ReelProvider.
    setState(() {
      isLiked = true; // For animation feedback
    });
    // Trigger the actual like/unlike via provider
    Provider.of<ReelProvider>(context, listen: false)
        .toggleReelLike(widget.reel.id); // You'll create this method in ReelProvider

    // Hide heart after animation (adjust duration for a smoother fade)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) { // Check if widget is still mounted before setState
        setState(() {
          isLiked = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // You'll need to consume ReelProvider to get the updated reel data
    // for actual like status and count.
    return Consumer<ReelProvider>( // Add Consumer here
      builder: (context, reelProvider, child) {
        // Get the latest Reel object from the provider
        final currentReel = reelProvider.reels.firstWhere(
              (r) => r.id == widget.reel.id,
          orElse: () => widget.reel, // Fallback to initial reel if not found
        );

        return VisibilityDetector(
          key: Key(currentReel.id), // Use currentReel.id for key
          onVisibilityChanged: _onVisibilityChanged,
          child: GestureDetector(
            onDoubleTap: _handleDoubleTapLike,
            // Remove onVerticalDragEnd here, as PageView.builder handles it.
            child: Stack(
              fit: StackFit.expand,
              children: [
                _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                    ? Chewie(controller: _chewieController!)
                    : const Center(child: CircularProgressIndicator()),

                // Gradient Overlay (Modern Instagram style often uses a darker top/bottom)
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
                      stops: [0.0, 0.3, 0.7, 1.0], // Adjust stops for desired fade
                    ),
                  ),
                ),

                // Heart animation on double tap (keep as is for visual feedback)
                if (isLiked)
                  Center(
                    child: Icon(Icons.favorite, color: Colors.white.withOpacity(0.8), size: 100),
                  ),

                // Left-aligned User Info (Top Left)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 650, // Adjust for status bar
                  left: 16,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(currentReel.userAvatar),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        currentReel.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Follow button (will be conditional based on follow status)
                      OutlinedButton(
                        onPressed: () { /* Implement follow logic via provider */ },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Follow', style: TextStyle(fontSize: 12)),
                      )
                    ],
                  ),
                ),

                // Right-side controls (Vertical Stack) - Modern Instagram style
                Positioned(
                  right: 10,
                  bottom: 30, // Adjust this based on bottom details height
                  child: Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          currentReel.isLiked ? Icons.favorite : Icons.favorite_border, // Use reel's actual like status
                          color: currentReel.isLiked ? Colors.red : Colors.white,
                          size: 30,
                        ),
                        onPressed: _handleDoubleTapLike, // Single tap should also like
                      ),
                      Text(
                        '${currentReel.likes}', // Use reel's actual likes
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 15),
                      IconButton(
                        icon: const Icon(Icons.comment, color: Colors.white, size: 30),
                        onPressed: () {
                          showCommentSection(context, currentReel.id); // Pass currentReel.id
                        },
                      ),
                      // Display comment count (if added to Reel model)
                      Text(
                        '${currentReel.commentCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 15),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white, size: 28),
                        onPressed: () {
                          Share.share(currentReel.videoUrl); // Share currentReel.videoUrl
                        },
                      ),
                      const SizedBox(height: 15),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                        onPressed: () { /* Implement more options/bottom sheet */ },
                      ),
                    ],
                  ),
                ),

                // Bottom details (Caption, Audio, etc.)
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 100, // Make room for right-side controls
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentReel.caption,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        maxLines: 2, // Limit caption lines
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.music_note, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Expanded( // Use Expanded for long audio titles
                            child: Text(
                              'Original Audio - Reel Music', // Consider making this dynamic
                              style: TextStyle(color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}