import 'package:Instagram/screens/commentscreen/comment_section.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';
import 'package:Instagram/screens/reels_screen/reel_modal.dart';

class ReelPlayer extends StatefulWidget {
  final Reel reel;
  final VoidCallback onSwipeUp;
  final VoidCallback onSwipeDown;

  const ReelPlayer({
    Key? key,
    required this.reel,
    required this.onSwipeUp,
    required this.onSwipeDown,
  }) : super(key: key);

  @override
  _ReelPlayerState createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool isLiked = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.reel.videoUrl);
    _videoController.initialize().then((_) {
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: false,
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
    if (info.visibleFraction > 0.5 && !_videoController.value.isPlaying) {
      _videoController.play();
    } else if (info.visibleFraction <= 0.5 && _videoController.value.isPlaying) {
      _videoController.pause();
    }
  }

  void _handleDoubleTapLike() {
    setState(() {
      isLiked = true;
    });
    // Simulate like logic here (e.g. call provider or Supabase)
    Future.delayed(Duration(milliseconds: 800), () {
      setState(() {
        isLiked = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return VisibilityDetector(
      key: Key(widget.reel.id),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onDoubleTap: _handleDoubleTapLike,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < 0) {
              widget.onSwipeUp();
            } else if (details.primaryVelocity! > 0) {
              widget.onSwipeDown();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _chewieController != null &&
                _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : const Center(child: CircularProgressIndicator()),

            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),

            // Heart animation on double tap
            if (isLiked)
              Center(
                child: Icon(Icons.favorite, color: Colors.white.withOpacity(0.8), size: 100),
              ),

            // Right-side controls
            Positioned(
              right: 10,
              bottom: 80,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(widget.reel.userAvatar),
                  ),
                  const SizedBox(height: 15),
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.white, size: 30),
                    onPressed: _handleDoubleTapLike,
                  ),
                  Text('${widget.reel.likes}', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 15),
                  IconButton(
                    icon: const Icon(Icons.comment, color: Colors.white, size: 30),
                    onPressed: () {
                      showCommentSection(context,widget.reel.id);
                    },
                  ),
                  const SizedBox(height: 15),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white, size: 28),
                    onPressed: () {
                      Share.share(widget.reel.videoUrl);
                    },
                  ),
                  const SizedBox(height: 15),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Bottom details
            Positioned(
              bottom: 20,
              left: 16,
              right: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(widget.reel.userAvatar),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.reel.username,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Follow', style: TextStyle(fontSize: 12)),
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.reel.caption,
                    style: const TextStyle(color: Colors.white),
                  ),

                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.music_note, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Original Audio - Reel Music',
                        style: TextStyle(color: Colors.white, fontSize: 12),
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
  }
}
