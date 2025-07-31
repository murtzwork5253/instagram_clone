import 'dart:async';
import 'package:Instagram/screens/profilescreen/current_user_profile.dart';
import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:Instagram/screens/reels_screen/reel_modal.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;

import '../../services/auth_service.dart';
import '../../widgets/expandable_caption_only.dart';
import '../chatscreen/chat_screen.dart';
import '../../services/insta_data_provider.dart';
import '../common/report_dialog.dart';
import '../profilescreen/other_user_profile_screen.dart';
import '../user_tagging/user_model.dart';
import '../user_tagging/user_tagging_service.dart';

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
  // late VideoPlayerController _videoController;
  VideoPlayerController? _videoController; // MODIFIED: Make it nullable
  ChewieController? _chewieController;
  bool isLiked = false;
  // bool _isInitialized = false;
  String? _error;
  AudioPlayer? _audioPlayer;
  bool _hasMusic = false;
  List<TaggedUser> _taggedUsers = [];
  final UserTaggingService _taggingService = UserTaggingService();
  bool _showMuteIcon = false;
  Timer? _muteIconTimer;
  bool _isLongPressing = false;

  // bool _isDisposed = false;

  // AppBar animation
  late AnimationController _appBarAnimationController;
  late Animation<double> _appBarAnimation;
  bool _isAppBarVisible = true;
  final ReelPlayerEnhancements _enhancements = ReelPlayerEnhancements();

  @override
  void initState() {
    super.initState();

    // Get controller from provider - it should be preloaded
    _videoController = Provider.of<ReelProvider>(context, listen: false)
        .getControllerForReel(widget.reel.id);

    // If controller exists and is initialized, build Chewie immediately
    if (_videoController != null && _videoController!.value.isInitialized) {
      _buildChewieController();
      print('✅ Using preloaded controller for reel ${widget.reel.id}');
    } else {
      // If not preloaded, initialize it now
      print('⚠️ Controller not preloaded for reel ${widget.reel.id}, initializing...');
      _initializeVideo();
    }

    _setupAppBarAnimation();
    _loadTaggedUsers();

    if (widget.isFirstReel) {
      _showAppBar();
    }
  }

  // NEW: A separate method to build the Chewie controller
  void _buildChewieController() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;

    // Set video volume before creating Chewie controller
    _handleVideoAudio();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: widget.isFirstReel, // Auto-play first reel immediately
      looping: true,
      showControls: false,
    );

    // This ensures the widget rebuilds once Chewie is ready
    if (mounted) {
      setState(() {});

      // For first reel, ensure it starts playing immediately
      if (widget.isFirstReel) {
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted && _videoController != null) {
            _videoController!.play();
          }
        });
      }
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

  void _toggleMute() {
    if (_videoController!.value.isInitialized) {
      final currentVolume = _videoController!.value.volume;
      final newVolume = currentVolume > 0 ? 0.0 : 1.0;
      _videoController!.setVolume(newVolume);

      // Update reel's mute state in provider if needed
      Provider.of<ReelProvider>(context, listen: false)
          .updateReelMuteState(widget.reel.id, newVolume == 0.0);

      HapticFeedback.lightImpact();
      // Show mute/unmute icon temporarily
      setState(() {
        _showMuteIcon = true;
      });

      // Cancel any existing timer
      _muteIconTimer?.cancel();

      // Hide icon after 2.5 seconds
      _muteIconTimer = Timer(Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _showMuteIcon = false;
          });
        }
      });


      // // Show feedback to user
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(newVolume == 0.0 ? 'Sound muted' : 'Sound unmuted'),
      //     duration: Duration(milliseconds: 800),
      //     behavior: SnackBarBehavior.floating,
      //     margin: EdgeInsets.only(bottom: 100),
      //   ),
      // );
    }
  }

  // MODIFIED: _initializeVideo is now a fallback
  Future<void> _initializeVideo() async {
    try {
      final reelProvider = Provider.of<ReelProvider>(context, listen: false);

      // Request the provider to load the controller for this reel.
      // This will either create it or return the existing initialization future.
      await reelProvider.preloadController(widget.reel.id);

      // By the time we get here, the controller should be in the map.
      _videoController = reelProvider.getControllerForReel(widget.reel.id);

      if (_videoController != null && _videoController!.value.isInitialized) {
        _buildChewieController();
      } else {
        // This case might happen if preloading fails.
        setState(() => _error = 'Failed to load video.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load video: $e';
        });
      }
    }
  }

  Future<void> _loadTaggedUsers() async {
    final taggedUsers = await _taggingService.getTaggedUsersFromReel(widget.reel.id);
    if (mounted) {
      setState(() {
        _taggedUsers = taggedUsers;
      });
    }
  }

  void _showTaggedUsersModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tagged People',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _taggedUsers.length,
                itemBuilder: (context, index) {
                  final user = _taggedUsers[index];
                  final imageUrl = getFullProfileImageUrl(user.profileImageUrl);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(
                      user.username,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OtherUserProfileScreen(userId: user.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? getFullProfileImageUrl(String? imageUrl) {
    if (imageUrl == null) return null;

    final isFullUrl = Uri.tryParse(imageUrl)?.hasAbsolutePath == true &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    return isFullUrl
        ? imageUrl
        : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$imageUrl';
  }


  // IMPORTANT MODIFICATION IN onVisibilityChanged
  void _onVisibilityChanged(VisibilityInfo info) async {
    if (!mounted) return;

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      print('⚠️ Controller not ready for reel ${widget.reel.id}');
      return;
    }

    if (info.visibleFraction > 0.8) {
      if (!controller.value.isPlaying) {
        try {
          await controller.play();
          print('✅ Video started for reel ${widget.reel.id}');
        } catch (e) {
          print('❌ Error starting video for reel ${widget.reel.id}: $e');
        }
      }
    } else {
      if (controller.value.isPlaying) {
        try {
          await controller.pause();
          print('⏸️ Video paused for reel ${widget.reel.id}');
        } catch (e) {
          print('❌ Error pausing video for reel ${widget.reel.id}: $e');
        }
      }
    }
  }

  void _handleVideoAudio() {
    if (_videoController!.value.isInitialized) {
      // Mute original video if reel has background music
      if (_hasMusic) {
        _videoController!.setVolume(0.0);
        print('🔇 Video muted (has background music)');
      } else {
        _videoController!.setVolume(widget.reel.isVideoMuted ? 0.0 : 1.0);
        print(
            '🔊 Video volume set to: ${widget.reel.isVideoMuted ? 0.0 : 1.0}');
      }
    }
  }

  void _handleDoubleTapLike() {
    setState(() {
      isLiked = true;
    });

    // Use enhanced like handler with haptic feedback
    _enhancements.handleDoubleTapLike(context, widget.reel.id);

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

  void _handleLongPressStart() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      setState(() {
        _isLongPressing = true;
      });
      _videoController!.pause();
      HapticFeedback.mediumImpact();
    }
  }

  void _handleLongPressEnd() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      setState(() {
        _isLongPressing = false;
      });
      _videoController!.play();
      HapticFeedback.lightImpact();
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
            onTap: _toggleMute,
            onLongPressStart: (_) => _handleLongPressStart(),
            onLongPressEnd: (_) => _handleLongPressEnd(),
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
                else if (_chewieController != null && _videoController!.value.isInitialized)
                  Chewie(controller: _chewieController!)
                else
                  Container(
                    color: Colors.black,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white,)),
                  ),

                // // Tagged Users List
                // _buildTaggedUsersList(),

                if (isLiked)
                  Center(
                    child: Icon(
                      Icons.favorite,
                      color: Colors.white.withOpacity(0.8),
                      size: 100,
                    ),
                  ),

                Consumer<ReelProvider>(
                  builder: (context, reelProvider, child) {
                    final currentReel = reelProvider.reels.firstWhere(
                          (r) => r.id == widget.reel.id,
                      orElse: () => widget.reel,
                    );

                    return AnimatedPositioned(
                      duration: Duration(milliseconds: 300),
                      left: MediaQuery.of(context).size.width / 2 - 35, // Center horizontally
                      top: MediaQuery.of(context).size.height / 2 - 135, // Center vertically
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: 300),
                        opacity: _showMuteIcon ? 1.0 : 0.0, // Show only when _showMuteIcon is true
                        child: Container(
                          width: 70,
                          height: 70,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(45),
                          ),
                          child: Icon(
                            currentReel.isVideoMuted ? Icons.volume_off : Icons.volume_up, // Show appropriate icon
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                _buildUserInfoSection(currentReel),
                _buildRightControls(currentReel),

                // Bottom Info Row
                Positioned(
                  left: 255,
                  right: 0,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    // decoration: BoxDecoration(
                    //   color: Colors.black.withOpacity(0.5),
                    //   borderRadius: BorderRadius.circular(18),
                    // ),
                    child: Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tagged Users Count
                        if (_taggedUsers.isNotEmpty)
                          GestureDetector(
                            onTap: _showTaggedUsersModal,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_taggedUsers.length} people',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserInfoSection(Reel currentReel) {
    return _enhancements.buildUserInfoSection(currentReel, context);
  }

  // Replace your Right Controls section in build method
  Widget _buildRightControls(Reel currentReel) {
    return _enhancements.buildRightControls(currentReel, context);
  }

  @override
  void dispose() {
    _appBarAnimationController.dispose();
    _chewieController?.dispose();
    _muteIconTimer?.cancel();
    // _isDisposed = true;
    // _videoController.dispose();
    super.dispose();
  }
}

class ReelPlayerEnhancements {
  // Enhanced double tap like handler with animation
  void handleDoubleTapLike(BuildContext context, String reelId) async {
    HapticFeedback.mediumImpact();

    try {
      await Provider.of<ReelProvider>(context, listen: false)
          .toggleReelLike(reelId);
    } catch (e) {
      // FIXED: Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red[700],
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Enhanced follow button handler
  void handleFollowTap(
      BuildContext context, String userId, String username) async {
    HapticFeedback.lightImpact();

    try {
      await Provider.of<ReelProvider>(context, listen: false)
          .toggleUserFollow(userId, username);
    } catch (e) {
      // FIXED: Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red[700],
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Enhanced share handler
  void handleShare(
      BuildContext context, String reelId, String username, String caption) {
    HapticFeedback.selectionClick();

    Provider.of<ReelProvider>(context, listen: false)
        .shareReel(reelId, username, caption);
  }

  // Show comment bottom sheet
  void showCommentBottomSheet(BuildContext context, String reelId) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(reelId: reelId),
    );
  }

  Widget buildUserInfoSection(Reel currentReel, BuildContext context) {
    return Consumer<ReelProvider>(
      builder: (context, reelProvider, child) {
        // FIXED: Get current user ID properly
        final currentUserId = AuthService.client().auth.currentUser?.id;
        final isOwnReel = currentUserId == currentReel.userId;

        return Positioned(
          bottom: 20,
          left: 16,
          right: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if(currentReel.userId == currentUserId)
                        // Navigate to user profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(),
                          ),
                        );
                      else
                        // Navigate to user profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtherUserProfileScreen(
                              userId: currentReel.userId,
                            ),
                          ),
                        );
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: currentReel.userAvatar.isNotEmpty
                          ? NetworkImage(currentReel.userAvatar)
                          : null,
                      backgroundColor: Colors.grey.shade700,
                      child: currentReel.userAvatar.isEmpty
                          ? Icon(Icons.person, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if(currentReel.userId == currentUserId)
                          // Navigate to user profile
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(),
                            ),
                          );
                        else
                          // Navigate to user profile
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OtherUserProfileScreen(
                                userId: currentReel.userId,
                              ),
                            ),
                          );
                      },
                      child: Text(
                        currentReel.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  // FIXED: Only show follow button for other users
                  if (!isOwnReel) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: OutlinedButton(
                        onPressed: () => handleFollowTap(
                            context, currentReel.userId, currentReel.username),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: currentReel.isFollowing
                                ? Colors.grey
                                : Colors.white,
                          ),
                          backgroundColor: currentReel.isFollowing
                              ? Colors.grey.withOpacity(0.3)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          currentReel.isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // REPLACED: Use the new expandable caption widget
              ExpandableCaptionOnly(
                caption: currentReel.caption,
                maxLines: 2,
                captionStyle: const TextStyle(color: Colors.white, fontSize: 15),
                moreStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.music_note,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Original Audio - ${currentReel.username}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // FIXED: Build enhanced right-side controls with proper state management
  Widget buildRightControls(Reel reel, BuildContext context) {
    return Consumer<ReelProvider>(
      builder: (context, reelProvider, child) {
        return Positioned(
          right: 10,
          bottom: 30,
          child: Column(
            children: [
              Consumer<ReelProvider>(
                builder: (context, reelProvider, _) {
                  final currentReel = reelProvider.reels.firstWhere(
                        (r) => r.id == reel.id,
                    orElse: () => reel, // fallback if not found
                  );

                  return Column(
                    children: [
                      // FIXED: Like button with proper animation and synced state
                      AnimatedScale(
                        scale: currentReel.isLiked ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: IconButton(
                          icon: Icon(
                            currentReel.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: currentReel.isLiked ? Colors.red : Colors.white,
                            size: 30,
                          ),
                          onPressed: () =>
                              reelProvider.toggleReelLike(currentReel.id),
                        ),
                      ),
                      Text(
                        _formatCount(currentReel.likes),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 15),

              // Comment button
              IconButton(
                icon: const Icon(OIcons.EvaIcons.message_circle_outline, color: Colors.white, size: 30),
                onPressed: () =>
                    showCommentBottomSheet(context, reel.id),
              ),
              Text(
                _formatCount(reel.commentCount),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),

              const SizedBox(height: 15),

              // Share button
              IconButton(
                icon: Image.asset("assets/icon/shareicon.png",color: Colors.white,width: 29,height: 39,),
                onPressed: () => handleShare(
                    context,
                    reel.id,
                    reel.username,
                    reel.caption
                ),
              ),

              const SizedBox(height: 15),

              // More options
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                onPressed: () => _showMoreOptions(context, reel),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to format large numbers
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  // Show full caption dialog
  void _showFullCaption(BuildContext context, String caption) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Caption',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          caption,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Show more options bottom sheet
  void _showMoreOptions(BuildContext context, Reel reel) {
    final currentUserId = AuthService.client().auth.currentUser?.id;
    final isOwnReel = currentUserId == reel.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show delete option only for reel owner
            if (isOwnReel) ...[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Reel',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteReel(context, reel);
                },
              ),
              Divider(color: Colors.grey.shade800),
            ],

            // Show report and block options only for other users' reels
            if (!isOwnReel) ...[
              ListTile(
                leading: const Icon(Icons.report, color: Colors.red),
                title: const Text('Report',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await showDialog(
                  context: context,
                  builder: (context) => ReportDialog(targetType: 'reel', targetId: reel.id),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block User',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  // Handle block user
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User blocked')),
                  );
                },
              ),
            ],

            // Common options for all users
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white),
              title: const Text('Copy Link',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: reel.videoUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),

            // Mute/Unmute option
            ListTile(
              leading: Icon(
                  reel.isVideoMuted ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white
              ),
              title: Text(
                  reel.isVideoMuted ? 'Unmute Video' : 'Mute Video',
                  style: TextStyle(color: Colors.white)
              ),
              onTap: () {
                Navigator.pop(context);
                // Toggle mute state
                Provider.of<ReelProvider>(context, listen: false)
                    .updateReelMuteState(reel.id, !reel.isVideoMuted);
              },
            ),
            // ADD THIS NEW TILE
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              title: const Text('Share in Chat',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _shareReelInChat(context, reel);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ADD THIS NEW METHOD
  void _shareReelInChat(BuildContext context, Reel reel) {
    final currentUserId = AuthService.client().auth.currentUser?.id;
    if (currentUserId == null) {
      // Handle case where user is not logged in, e.g., show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to share reels.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          currentUserId: currentUserId,
          sharedReel: reel, // Pass the reel to the chat screen
        ),
      ),
    );
  }

  // NEW CODE - Replace the above section with this:
  Future<void> _deleteReel(BuildContext context, Reel reel) async {
    print('DEBUG: _deleteReel method called.');

    try {
      // Ensure providers are accessible here
      final reelProvider = Provider.of<ReelProvider>(context, listen: false);
      // final authService = Provider.of<AuthService>(context, listen: false);

      print('DEBUG: ReelProvider and AuthService accessed successfully.');
      print('DEBUG: Reel ID to delete: ${reel.id}');
      print('DEBUG: Reel owner ID: ${reel.userId}');

      final currentUserId = AuthService.client().auth.currentUser?.id;
      // Ownership check (good to have explicitly here too, though provider does it)
      if ( currentUserId != reel.userId) {
        print('DEBUG: Ownership mismatch detected in ReelPlayer. Current user is NOT the owner.');
        if(!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only delete your own reels!'),
            backgroundColor: Colors.orange,
          ),
        );
        return; // Exit early if not owner
      }

      final bool confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Delete Reel'),
            content: Text('Are you sure you want to delete this reel? This action cannot be undone.'),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      ) ?? false;

      if (confirmDelete) {
        print('DEBUG: User confirmed deletion for reel ID: ${reel.id}');
        // if(!context.mounted) return;
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Deleting reel...')),
        // );

        print('DEBUG: Preparing to call reelProvider.deleteReel...'); // <-- NEW LINE
        print('DEBUG: ReelProvider instance hashCode: ${reelProvider.hashCode}'); // <-- NEW LINE

        print('DEBUG: Calling reelProvider.deleteReel...');
        await reelProvider.deleteReel(
          reel.id,
          onSuccess: () {
            if(!context.mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Reel deleted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            print('DEBUG: Reel deleted successfully via provider callback.');
            // You might want to navigate back or update the UI more explicitly here.
            // For example, if this reel is part of a list, you'd want to remove it from the list view.
            // Navigator.of(context).pop(); // Example to pop the screen if it's a detail view
          },
          onError: (errorMessage) {
            if(!context.mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting reel: $errorMessage'),
                backgroundColor: Colors.red,
              ),
            );
            print('DEBUG: Error from provider onError callback: $errorMessage');
          },
        );
        print('DEBUG: reelProvider.deleteReel call finished (await completed).');

      } else {
        print('DEBUG: User cancelled deletion.');
      }
    } on ProviderNotFoundException catch (e) {
      print('ERROR: ProviderNotFoundException in _deleteReel: $e');
      if(!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ReelProvider not found in widget tree.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e, s) {
      if(!context.mounted) return;
      // Catch any other unexpected errors that might occur during the process
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred during deletion: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('ERROR: Caught unexpected error in _deleteReel: $e');
      print('STACK TRACE: $s');
    }
  }
}

// Comment Bottom Sheet Widget
class CommentBottomSheet extends StatefulWidget {
  final String reelId;

  const CommentBottomSheet({Key? key, required this.reelId}) : super(key: key);

  @override
  _CommentBottomSheetState createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  // List<Map<String, dynamic>> comments = [];
  bool isLoading = true;
  bool _canPost = false;
  bool _isPosting = false;
  DateTime? _lastRefreshed;
  final String currentUserId = AuthService.client().auth.currentUser!.id;
  final ScrollController _textFieldScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_updatePostButton);
    // Use addPostFrameCallback to safely call provider after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComments();
    });
  }

  @override
  void dispose() {
    _commentController.removeListener(_updatePostButton);
    _commentController.dispose();
    _textFieldScrollController.dispose();
    super.dispose();
  }

  void _updatePostButton() {
    setState(() {
      _canPost = _commentController.text.trim().isNotEmpty;
    });
  }

  String _formatLastUpdated(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _loadComments() async {
    setState(() => isLoading = true);
    try {
      // Just tell the provider to fetch. The UI will update via the Consumer.
      await Provider.of<ReelProvider>(context, listen: false)
          .getReelCommentsWithLikes(widget.reelId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _addComment() async {
    if (!_canPost || _isPosting) return;

    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final reelProvider = Provider.of<ReelProvider>(context, listen: false);

    setState(() {
      _isPosting = true;
    });

    try {
      await reelProvider.addComment(widget.reelId, content);
      _commentController.clear();

      // FIXED: Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comment added successfully'),
            backgroundColor: Colors.green[700],
            duration: Duration(seconds: 2),
          ),
        );
      }

      await Future.delayed(Duration(milliseconds: 200));
      // Refresh comments
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red[700],
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  // Add this method to your State class (works for both comment sections)

  String? _getCurrentUserProfileImageUrl(BuildContext context) {
    try {
      // Get current user from provider
      final dataProvider = Provider.of<InstaDataProvider>(context, listen: false);
      final currentUser = dataProvider.currentUser;

      if (currentUser?.profileImageUrl == null || currentUser!.profileImageUrl!.isEmpty) {
        return null;
      }

      final imageUrl = currentUser.profileImageUrl!;

      // Check if it's already a full URL (starts with http/https)
      final isPublicUrl = imageUrl.startsWith('http');

      if (isPublicUrl) {
        return imageUrl;
      } else {
        // Convert relative path to full Supabase URL
        return Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(imageUrl);
      }
    } catch (e) {
      print('Error fetching current user profile image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReelProvider>(
        builder: (context,reelProvider,child) {
          final comments = reelProvider.currentComments;
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                return AnimatedPadding(
                  duration: Duration(milliseconds: 250),
                  padding: EdgeInsets.only(bottom: bottomInset),
                  curve: Curves.easeOut,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.85,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Handle bar
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade600,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          // Header
                          Container(
                            padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey.shade800, width: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(width: 24), // Balance the close button
                                Text(
                                  'Comments',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Last refreshed indicator
                          if (_lastRefreshed != null)
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              width: double.infinity,
                              alignment: Alignment.center,
                              child: Text(
                                'Last updated ${_formatLastUpdated(_lastRefreshed!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),

                          // Comments list
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _loadComments,
                              color: Colors.white,
                              backgroundColor: Colors.grey[800],
                              child: (isLoading && comments.isEmpty)
                                  ? Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                                  : comments.isEmpty
                                  ? Center(
                                child: ListView(
                                  physics:
                                  const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    Container(
                                      height: MediaQuery.of(context)
                                          .size
                                          .height /
                                          3,
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 50,
                                            color: Colors.grey.shade600,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No comments yet',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Start the conversation.',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                                  : ListView.builder(
                                physics:
                                const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(vertical: 8),
                                itemCount: comments.length,
                                itemBuilder: (context, index) {
                                  final comment = comments[index];
                                  return AnimatedSwitcher(
                                    duration: Duration(milliseconds: 300),
                                    child: ReelCommentTile(
                                      key: ValueKey(comment['id']),
                                      comment: comment,
                                      currentUserId: currentUserId,
                                      reelId: widget.reelId,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          //Add comment section
                          Container(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 12,
                              bottom: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade800, width: 0.5),
                              ),
                            ),
                            child: SafeArea(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end, // Changed to end alignment
                                children: [
                                  // Current user profile image
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0), // Add bottom padding
                                    child: Consumer<ReelProvider>(
                                      builder: (context, reelProvider, child) {
                                        return CircleAvatar(
                                          radius: 18,
                                          backgroundImage: _getCurrentUserProfileImageUrl(context) != null
                                              ? NetworkImage(_getCurrentUserProfileImageUrl(context)!)
                                              : null,
                                          backgroundColor: Colors.grey.shade700,
                                          child: _getCurrentUserProfileImageUrl(context) == null
                                              ? Icon(Icons.person, color: Colors.white, size: 20)
                                              : null,
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 12),

                                  // Comment text field with scroll
                                  Expanded(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxHeight: 100, // Maximum height for ~4 lines
                                        minHeight: 40,  // Minimum height for single line
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade900,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey.shade800),
                                      ),
                                      child: Scrollbar(
                                        controller: _textFieldScrollController,
                                        thumbVisibility: false, // Hide scrollbar
                                        child: SingleChildScrollView(
                                          controller: _textFieldScrollController,
                                          child: TextField(
                                            controller: _commentController,
                                            scrollController: null, // Remove internal scroll
                                            style: TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              hintText: 'Add a comment...',
                                              border: InputBorder.none,
                                              hintStyle: TextStyle(color: Colors.grey.shade600),
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            maxLines: null,
                                            minLines: 1,
                                            textAlignVertical: TextAlignVertical.top,
                                            textInputAction: TextInputAction.send,
                                            onChanged: (text) {
                                              // Auto-scroll to bottom when typing
                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                if (_textFieldScrollController.hasClients) {
                                                  _textFieldScrollController.animateTo(
                                                    _textFieldScrollController.position.maxScrollExtent,
                                                    duration: Duration(milliseconds: 100),
                                                    curve: Curves.easeOut,
                                                  );
                                                }
                                              });
                                            },
                                            onSubmitted: (_) {
                                              if (_canPost) _addComment();
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),

                                  // Post button
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0), // Add bottom padding
                                    child: GestureDetector(
                                      onTap: (_canPost && !_isPosting) ? _addComment : null,
                                      child: Container(
                                        padding: EdgeInsets.all(8),
                                        child: _isPosting
                                            ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                          ),
                                        )
                                            : Icon(
                                          Icons.send,
                                          color: _canPost ? Colors.blue : Colors.grey.shade600,
                                          size: 24,
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
                );
              },
            ),
          );
        }
    );
  }
}

// Enhanced Comment Tile Widget - FIXED VERSION
class ReelCommentTile extends StatefulWidget {
  final Map<String, dynamic> comment;
  final String currentUserId;
  final String reelId;

  const ReelCommentTile({
    Key? key,
    required this.comment,
    required this.currentUserId,
    required this.reelId,
  }) : super(key: key);

  @override
  State<ReelCommentTile> createState() => _ReelCommentTileState();
}

class _ReelCommentTileState extends State<ReelCommentTile> {
  bool _isExpanded = false;

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'just now';
  }

  // FIXED: Toggle like method that properly updates the provider
  void _toggleLike() async {
    final reelProvider = Provider.of<ReelProvider>(context, listen: false);

    try {
      // Call the provider method and let it handle the state management
      await reelProvider.toggleCommentLike(widget.comment['id']);

      // Optional: Add haptic feedback
      HapticFeedback.lightImpact();

    } catch (e) {
      // Show error message if like toggle fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update like: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _deleteComment() async {
    final provider = Provider.of<ReelProvider>(context, listen: false);

    // Show confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text(
            'Delete Comment?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this comment? This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
            TextButton(
              onPressed: () async {
                await provider.deleteCommentWithFeedback(
                  widget.reelId,
                  widget.comment,
                  onError: (message) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                  onSuccess: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Comment deleted successfully')),
                    );
                  },
                );
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final commentText = comment['comment'] as String;
    final username = comment['username'] as String;
    final userAvatar = comment['userAvatar'] as String;
    final createdAt = comment['createdAt'] as DateTime;
    final commentId = comment['id'] as String;

    // FIXED: Get like state from the comment data directly
    final bool isLiked = comment['is_liked'] ?? false;
    final int likeCount = comment['likes'] ?? 0;

    final String contentPreview = commentText.length > 120
        ? commentText.substring(0, 120) + '...'
        : commentText;

    final bool isTruncated = commentText.length > 120;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: GestureDetector(
        onLongPress: _deleteComment,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Avatar
            CircleAvatar(
              radius: 18,
              backgroundImage:
              userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
              backgroundColor: Colors.grey.shade700,
              child: userAvatar.isEmpty
                  ? Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12),

            // Comment Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username and comment text
                  GestureDetector(
                    onTap: _isExpanded ? () {
                      setState(() {
                        _isExpanded = false;
                      });
                    } : (){
                      setState(() {
                        _isExpanded = true;
                      });
                    },
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: username,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: ' ',
                            style: TextStyle(fontSize: 14),
                          ),
                          TextSpan(
                            text: _isExpanded || !isTruncated
                                ? commentText
                                : contentPreview,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (isTruncated)
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _isExpanded ? 'less' : 'more',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                    ),

                  SizedBox(height: 6),

                  // Time, likes, and reply
                  Row(
                    children: [
                      Text(
                        _getTimeAgo(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(width: 16),
                      // FIXED: Use actual like count from comment data
                      if (likeCount > 0)
                        Text(
                          '$likeCount ${likeCount == 1 ? 'like' : 'likes'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      SizedBox(width: 16),
                      InkWell(
                        onTap: () {
                          // TODO: Add reply functionality
                        },
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // FIXED: Like button that uses actual comment data
            GestureDetector(
              onTap: _toggleLike,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: AnimatedScale(
                  scale: isLiked ? 1.2 : 1.0,
                  duration: Duration(milliseconds: 150),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey.shade600,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
