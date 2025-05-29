import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/insta_data_provider.dart';

class StoryViewScreen extends StatefulWidget {
  final List<StoryData> stories;
  final int initialIndex;

  const StoryViewScreen({
    Key? key,
    required this.stories,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentIndex = 0;
  bool _isPaused = false;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        if (_animationController.value == 1.0) _nextStory();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      });

    _startTimer();
    _markStoryAsViewed(widget.stories[_currentIndex].id!);
  }

  // <--- ADD THIS HELPER FUNCTION (copy from home_screen_feed.dart) ---
  String _formatTime(DateTime? time) {
    if (time == null) return '';

    final difference = DateTime.now().difference(time);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(time);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

  // --- END ADDED HELPER FUNCTION ---

  void _startTimer() {
    _animationController.reset();
    _animationController.forward();
    _isPaused = false;
  }

  void _pauseTimer() {
    _animationController.stop();
    _isPaused = true;
    setState(() {
      _showUI = false;
    });
  }

  void _resumeTimer() {
    if (_animationController.value < 1.0) {
      _animationController.forward();
      _isPaused = false;
    }
    setState(() {
      _showUI = true;
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      _startTimer();
      _markStoryAsViewed(widget.stories[_currentIndex].id!);
    } else {
      Provider.of<InstaDataProvider>(context, listen: false).reloadData();
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      _startTimer();
    } else {
      Provider.of<InstaDataProvider>(context, listen: false).reloadData();
      Navigator.of(context).pop();
    }
  }

  void _markStoryAsViewed(String storyId) {
    final story = widget.stories[_currentIndex];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    Provider.of<InstaDataProvider>(context, listen: false)
        .viewStory(storyId, story.userId); // Pass both IDs
  }

  String? _buildProfileImageUrl(String? url) {
    const supabasePublicBase =
        'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/';
    if (url == null || url.isEmpty) return null;
    if (Uri.tryParse(url)?.hasAbsolutePath ?? false) return url;
    return '$supabasePublicBase$url';
  }

  void _showStoryOptions() async {
    final currentStory = widget.stories[_currentIndex];
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentStory.isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Story'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement delete functionality here
                },
              ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Story'),
              onTap: () {
                Navigator.pop(context);
                // Implement share functionality here
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report Story'),
              onTap: () {
                Navigator.pop(context);
                // Implement report functionality here
              },
            ),
          ],
        );
      },
    );
    _resumeTimer();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStory = widget.stories[_currentIndex];

    Color profileBorderColor = Colors.grey;
    if (currentStory.isMe && currentStory.hasStory) {
      profileBorderColor = currentStory.isViewed ? Colors.grey : Colors.purple;
    } else if (!currentStory.isMe && !currentStory.isViewed) {
      profileBorderColor = Colors.orange;
    }
    // debugPrint("Story time: ${currentStory.createdAt}");

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pauseTimer(),
        onLongPressEnd: (_) => _resumeTimer(),
        child: Stack(
          children: [
            // Story Content
            Center(
              child: AspectRatio(
                aspectRatio: 8.5 / 16,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.stories.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final story = widget.stories[index];
                    return Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          story.mediaUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                  child: Icon(Icons.error,
                                      color: Colors.red, size: 50)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Navigation Tap Zones
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _previousStory,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _nextStory,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ],
            ),

            // Top Info & Progress
            Visibility(
              visible: _showUI,
              child: Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: List.generate(widget.stories.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2.0),
                              child: LinearProgressIndicator(
                                value: index == _currentIndex
                                    ? _animationController.value
                                    : (index < _currentIndex ? 1.0 : 0.0),
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                minHeight: 3,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Container(
                            child: CircleAvatar(
                                radius: 20,
                                backgroundImage: NetworkImage(
                                  _buildProfileImageUrl(
                                      currentStory.profileImageUrl)!,
                                )),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentStory.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          if (currentStory.createdAt != null)
                            Text(
                              _formatTime(currentStory.createdAt),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.more_vert_outlined,
                                color: Colors.white, size: 26),
                            onPressed: () {
                              _pauseTimer();
                              _showStoryOptions();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Right Like Button
            Visibility(
              visible: !currentStory.isMe && _showUI,
              child: Positioned(
                bottom: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Like story functionality coming soon!')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.favorite_border,
                        color: Colors.white, size: 30),
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
