import 'package:Instagram/screens/commentscreen/comment_section.dart';
import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';
import 'package:Instagram/screens/reels_screen/reel_modal.dart';

class ReelPlayer extends StatefulWidget {
  final Reel reel;
  final bool isFirstReel; // Add this to know if it's the first reel

  const ReelPlayer({
    Key? key,
    required this.reel,
    this.isFirstReel = false,
  }) : super(key: key);

  @override
  _ReelPlayerState createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool isLiked = false;
  bool _isInitialized = false;
  String? _error;

  // AppBar animation
  late AnimationController _appBarAnimationController;
  late Animation<double> _appBarAnimation;
  bool _isAppBarVisible = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _setupAppBarAnimation();

    // Show app bar initially for first reel
    if (widget.isFirstReel) {
      _showAppBar();
    }
  }

  void _setupAppBarAnimation() {
    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _appBarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _appBarAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start with app bar visible for first reel
    if (widget.isFirstReel) {
      _appBarAnimationController.forward();
    }
  }

  void _showAppBar() {
    if (!_isAppBarVisible) {
      setState(() => _isAppBarVisible = true);
      _appBarAnimationController.forward();
    }
  }

  void _hideAppBar() {
    if (_isAppBarVisible) {
      setState(() => _isAppBarVisible = false);
      _appBarAnimationController.reverse();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.network(widget.reel.videoUrl);
      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: true,
        showControls: false,
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load video: $e';
      });
    }
  }

  @override
  void dispose() {
    _appBarAnimationController.dispose();
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_isInitialized && _videoController.value.isInitialized) {
      if (info.visibleFraction > 0.5 && !_videoController.value.isPlaying) {
        _videoController.play();
        // Show app bar when this reel becomes visible and it's the first one
        if (widget.isFirstReel) {
          _showAppBar();
        }
      } else if (info.visibleFraction <= 0.5 &&
          _videoController.value.isPlaying) {
        _videoController.pause();
      }
    }
  }

  void _handleDoubleTapLike() {
    setState(() {
      isLiked = true;
    });

    Provider.of<ReelProvider>(context, listen: false)
        .toggleReelLike(widget.reel.id);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          isLiked = false;
        });
      }
    });
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    // Hide app bar when user starts scrolling down
    if (details.delta.dy > 5) {
      _hideAppBar();
    }
    // Show app bar when user scrolls up significantly
    else if (details.delta.dy < -10) {
      _showAppBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReelProvider>(
      builder: (context, reelProvider, child) {
        final currentReel = reelProvider.reels.firstWhere(
          (r) => r.id == widget.reel.id,
          orElse: () => widget.reel,
        );

        return VisibilityDetector(
          key: Key(currentReel.id),
          onVisibilityChanged: _onVisibilityChanged,
          child: GestureDetector(
            onDoubleTap: _handleDoubleTapLike,
            onPanUpdate: _handleVerticalDrag,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video Player
                if (_error != null)
                  Container(
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (_isInitialized && _chewieController != null)
                  Chewie(controller: _chewieController!)
                else
                  Container(
                    color: Colors.black,
                    child: const Center(child: CircularProgressIndicator()),
                  ),

                if (isLiked)
                  Center(
                    child: Icon(
                      Icons.favorite,
                      color: Colors.white.withOpacity(0.8),
                      size: 100,
                    ),
                  ),

                // User Info (Bottom Left)
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
                            radius: 18,
                            backgroundImage:
                                NetworkImage(currentReel.userAvatar),
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
                          const SizedBox(width: 9),
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Follow',
                                style: TextStyle(fontSize: 12)),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentReel.caption,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.music_note, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Original Audio - Reel Music',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),

                // Right-side controls
                Positioned(
                  right: 10,
                  bottom: 30,
                  child: Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          currentReel.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color:
                              currentReel.isLiked ? Colors.red : Colors.white,
                          size: 30,
                        ),
                        onPressed: _handleDoubleTapLike,
                      ),
                      Text(
                        '${currentReel.likes}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 15),
                      IconButton(
                        icon: const Icon(Icons.comment,
                            color: Colors.white, size: 30),
                        onPressed: () {
                          showCommentSection(context, currentReel.id);
                        },
                      ),
                      Text(
                        '${currentReel.commentCount}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 15),
                      IconButton(
                        icon: const Icon(Icons.share,
                            color: Colors.white, size: 28),
                        onPressed: () {
                          Share.share(currentReel.videoUrl);
                        },
                      ),
                      const SizedBox(height: 15),
                      IconButton(
                        icon: const Icon(Icons.more_vert,
                            color: Colors.white, size: 28),
                        onPressed: () {},
                      ),
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
