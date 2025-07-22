import 'package:Instagram/screens/homescreen/story_views_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/insta_data_provider.dart';
import '../common/report_dialog.dart';
import '../user_tagging/user_model.dart';
import '../user_tagging/user_tagging_service.dart';

class StoryViewScreen extends StatefulWidget {
  final List<StoryData> stories;
  final int initialIndex;
  final List<int> userStartIndices;

  const StoryViewScreen({
    Key? key,
    required this.stories,
    this.initialIndex = 0,
    this.userStartIndices = const [],
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
  List<TaggedUser> _taggedUsers = [];
  final UserTaggingService _taggingService = UserTaggingService();
  // Story views feature state
  List<StoryViewer> _topViewers = [];
  int _totalViewsCount = 0;

  // Like feature state
  bool _isLiked = false;
  bool _likeLoading = false;


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
    _loadTaggedUsers(widget.stories[_currentIndex].id!);
    _checkIfLiked(widget.stories[_currentIndex].id!);
    _loadStoryViewers(widget.stories[_currentIndex].id!);

    // FIX: Move precaching to post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheStoryMedia(_currentIndex);
    });
  }

  void _precacheStoryMedia(int index) {
    final context = this.context;
    final story = widget.stories[index];
    if (story.mediaUrl != null && story.mediaUrl!.isNotEmpty) {
      precacheImage(CachedNetworkImageProvider(story.mediaUrl!), context);
    }
    if (story.profileImageUrl != null && story.profileImageUrl!.isNotEmpty) {
      final profileUrl = _buildProfileImageUrl(story.profileImageUrl);
      if (profileUrl != null) {
        precacheImage(CachedNetworkImageProvider(profileUrl), context);
      }
    }
  }

  Future<void> _loadTaggedUsers(String storyId) async {
    final taggedUsers = await _taggingService.getTaggedUsersFromStory(storyId);
    if (mounted) {
      setState(() {
        _taggedUsers = taggedUsers;
      });
    }
  }

  Future<void> _checkIfLiked(String storyId) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLiked = false);
      return;
    }
    final res = await supabase
        .from('story_likes')
        .select('id')
        .eq('story_id', storyId)
        .eq('user_id', userId)
        .maybeSingle();
    setState(() {
      _isLiked = res != null;
    });
  }

  Future<void> _toggleLike(String storyId) async {
    if (_likeLoading) return;
    setState(() => _likeLoading = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _likeLoading = false);
      return;
    }
    if (_isLiked) {
      // Unlike
      await supabase
          .from('story_likes')
          .delete()
          .eq('story_id', storyId)
          .eq('user_id', userId);
      setState(() {
        _isLiked = false;
        _likeLoading = false;
      });
    } else {
      // Like
      await supabase.from('story_likes').insert({
        'story_id': storyId,
        'user_id': userId,
      });
      setState(() {
        _isLiked = true;
        _likeLoading = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _markStoryAsViewed(widget.stories[index].id!);
    _loadTaggedUsers(widget.stories[index].id!);
    _checkIfLiked(widget.stories[index].id!);
    _loadStoryViewers(widget.stories[index].id!);
    _resumeTimer();
    _precacheStoryMedia(index);
  }

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

  Future<void> _loadStoryViewers(String storyId) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await Supabase.instance.client
          .rpc('get_story_viewers', params: {
        'story_id_param': storyId,
        'current_user_id': currentUserId,
      });

      print('Story viewers for $storyId: $response'); // Debug log

      final viewersList = <StoryViewer>[];
      for (final item in response) {
        viewersList.add(StoryViewer(
          viewerId: item['viewer_id'],
          username: item['username'] ?? 'Unknown',
          profileImageUrl: item['profile_image_url'],
          viewedAt: DateTime.parse(item['viewed_at']),
        ));
      }

      if (mounted) {
        setState(() {
          _totalViewsCount = viewersList.length;
          _topViewers = viewersList.take(3).toList();
        });
      }
    } catch (e) {
      print('Error loading story viewers: $e');
    }
  }

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

  int _getUserIndexForStory(int storyIndex) {
    for (int i = 0; i < widget.userStartIndices.length; i++) {
      if (i == widget.userStartIndices.length - 1 ||
          (storyIndex >= widget.userStartIndices[i] &&
              storyIndex < widget.userStartIndices[i + 1])) {
        return i;
      }
    }
    return widget.userStartIndices.length - 1;
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

  // NEW: Get stories for current user
  List<StoryData> _getStoriesForCurrentUser() {
    final currentUserIndex = _getUserIndexForStory(_currentIndex);
    final startIndex = widget.userStartIndices[currentUserIndex];
    final endIndex = (currentUserIndex == widget.userStartIndices.length - 1)
        ? widget.stories.length
        : widget.userStartIndices[currentUserIndex + 1];

    return widget.stories.sublist(startIndex, endIndex);
  }

  // NEW: Get current story index within user's stories
  int _getCurrentStoryIndexInUser() {
    final currentUserIndex = _getUserIndexForStory(_currentIndex);
    final startIndex = widget.userStartIndices[currentUserIndex];
    return _currentIndex - startIndex;
  }

  void _nextStory() {
    final currentUserIndex = _getUserIndexForStory(_currentIndex);
    final nextIndex = _currentIndex + 1;

    // Check if we're at the last story overall
    if (nextIndex >= widget.stories.length) {
      Navigator.pop(context);
      return;
    }

    final nextUserIndex = _getUserIndexForStory(nextIndex);

    // If moving to a different user, use page transition
    if (currentUserIndex != nextUserIndex) {
      _transitionToUser(nextUserIndex);
    } else {
      // Same user, just move to next story
      setState(() {
        _currentIndex = nextIndex;
      });
      _pageController.jumpToPage(_currentIndex);
      _markStoryAsViewed(widget.stories[_currentIndex].id!);
      _loadTaggedUsers(widget.stories[_currentIndex].id!);
      _startTimer();
    }
  }

  void _previousStory() {
    final currentUserIndex = _getUserIndexForStory(_currentIndex);
    final previousIndex = _currentIndex - 1;

    // If at the first story, exit
    if (previousIndex < 0) {
      Provider.of<InstaDataProvider>(context, listen: false).reloadData();
      Navigator.of(context).pop();
      return;
    }

    final previousUserIndex = _getUserIndexForStory(previousIndex);

    // If moving to a different user, use page transition
    if (currentUserIndex != previousUserIndex) {
      _transitionToUser(previousUserIndex, goToLast: true);
    } else {
      // Same user, just move to previous story
      setState(() {
        _currentIndex = previousIndex;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      _markStoryAsViewed(widget.stories[_currentIndex].id!);
      _loadTaggedUsers(widget.stories[_currentIndex].id!);
      _startTimer();
    }
  }

  // NEW: Transition to a different user with animation
  void _transitionToUser(int userIndex, {bool goToLast = false}) {
    final targetStoryIndex = goToLast
        ? (userIndex == widget.userStartIndices.length - 1
        ? widget.stories.length - 1
        : widget.userStartIndices[userIndex + 1] - 1)
        : widget.userStartIndices[userIndex];

    setState(() {
      _currentIndex = targetStoryIndex;
    });

    _pageController.animateToPage(
      _currentIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) {
      _markStoryAsViewed(widget.stories[_currentIndex].id!);
      _loadTaggedUsers(widget.stories[_currentIndex].id!);
      _startTimer();
    });
  }

  // MODIFIED: Handle tap navigation with user detection
  void _handleTapNavigation(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final isRightSide = details.globalPosition.dx > width / 2;

    if (isRightSide) {
      _nextStory();
    } else {
      _previousStory();
    }
  }

  void _markStoryAsViewed(String storyId) {
    final story = widget.stories[_currentIndex];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId != null && currentUserId != story.userId) {
      _recordStoryView(storyId, currentUserId);
    }
    Provider.of<InstaDataProvider>(context, listen: false)
        .viewStory(storyId, story.userId);

  }

  Future<void> _recordStoryView(String storyId, String viewerId) async {
    try {
      // print('Attempting to record story view - Story ID: $storyId, Viewer ID: $viewerId');

      final result = await Supabase.instance.client
          .from('story_views')
          .upsert({
        'story_id': storyId,
        'viewer_id': viewerId,
        'viewed_at': DateTime.now().toIso8601String(),
      });

      // print('Story view recorded successfully: $result');

      // Verify the record was created
      final verification = await Supabase.instance.client
          .from('story_views')
          .select('*')
          .eq('story_id', storyId)
          .eq('viewer_id', viewerId);

      // print('Verification of recorded view: $verification');
    } catch (e) {
      print('Error recording story view: $e');
    }
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
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await SupabaseService().deleteStory(currentStory.id!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Story deleted')),
                    );
                    Navigator.of(context).pop();
                    await Provider.of<InstaDataProvider>(context, listen: false).refreshFeed();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete story: $e')),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Report Story', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await showDialog(
                  context: context,
                  builder: (context) => ReportDialog(
                    targetType: 'story',
                    targetId: currentStory.id!,
                  ),
                );
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
    final currentUserStories = _getStoriesForCurrentUser();
    final currentStoryInUser = _getCurrentStoryIndexInUser();

    Color profileBorderColor = Colors.grey;
    if (currentStory.isMe && currentStory.hasStory) {
      profileBorderColor = currentStory.isViewed ? Colors.grey : Colors.purple;
    } else if (!currentStory.isMe && !currentStory.isViewed) {
      profileBorderColor = Colors.orange;
    }

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
                  onPageChanged: _onPageChanged,
                  itemCount: widget.stories.length,
                  itemBuilder: (context, index) {
                    final story = widget.stories[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Story Image/Video
                        CachedNetworkImage(
                          imageUrl: story.mediaUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),

                        // Tagged Users Overlay
                        if (_taggedUsers.isNotEmpty)
                          Positioned(
                            top: 100,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _taggedUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _taggedUsers[index];
                                  return Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: user.profileImageUrl != null
                                              ? NetworkImage(user.profileImageUrl!)
                                              : null,
                                          child: user.profileImageUrl == null
                                              ? const Icon(Icons.person, size: 20)
                                              : null,
                                        ),
                                        Text(
                                          user.username,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                offset: Offset(0, 1),
                                                blurRadius: 3.0,
                                                color: Colors.black,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // MODIFIED: Navigation Tap Zones
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTapUp: _handleTapNavigation,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTapUp: _handleTapNavigation,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ],
            ),

            // MODIFIED: Top Info & Progress - Show progress for current user only
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
                        children: List.generate(currentUserStories.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: LinearProgressIndicator(
                                value: index == currentStoryInUser
                                    ? _animationController.value
                                    : (index < currentStoryInUser ? 1.0 : 0.0),
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
                                  _buildProfileImageUrl(currentStory.profileImageUrl)!,
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
                          const SizedBox(width: 8),
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
                  onTap: _likeLoading
                      ? null
                      : () => _toggleLike(currentStory.id!),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: _likeLoading
                        ? const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: Colors.white,
                            size: 30,
                          ),
                  ),
                ),
              ),
            ),

            //Bottom Left Story Views
            Visibility(
              visible: currentStory.isMe && _showUI,
              child: Positioned(
                bottom: 40,
                left: 20,
                child: GestureDetector(
                  onTap: () async {
                    _pauseTimer();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StoryViewsScreen(
                          storyId: currentStory.id!,
                        ),
                      ),
                    );
                    _resumeTimer();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // Add this
                    children: [
                      // Top 3 viewers profile pics
                      if (_topViewers.isNotEmpty)
                        SizedBox( // Wrap Container with SizedBox to give it constraints
                          width: 80, // Set a fixed width
                          height: 30,
                          child: Stack(
                            children: [
                              for (int i = 0; i < _topViewers.length && i < 3; i++)
                                Positioned(
                                  left: i * 20.0,
                                  child: Container(
                                    width: 30, // Add explicit width
                                    height: 30, // Add explicit height
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: Colors.white,
                                      child: CircleAvatar(
                                        radius: 13,
                                        backgroundImage: _topViewers[i].profileImageUrl != null
                                            ? CachedNetworkImageProvider(
                                            _buildProfileImageUrl(_topViewers[i].profileImageUrl)!)
                                            : null,
                                        child: _topViewers[i].profileImageUrl == null
                                            ? const Icon(Icons.person, size: 15, color: Colors.grey)
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 5),
                      Text(
                        _totalViewsCount > 0 ? 'Views' : 'Views',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
class StoryViewer {
  final String viewerId;
  final String username;
  final String? profileImageUrl;
  final DateTime viewedAt;

  StoryViewer({
    required this.viewerId,
    required this.username,
    this.profileImageUrl,
    required this.viewedAt,
  });
}