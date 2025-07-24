import 'package:Instagram/screens/commentscreen/comment_section.dart';
import 'package:Instagram/screens/createscreens/create_post/create_post_screen.dart';
import 'package:Instagram/screens/homescreen/story_view_screen.dart';
import 'package:Instagram/screens/profilescreen/current_user_profile.dart';
import 'package:Instagram/screens/profilescreen/other_user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
import '../chatscreen/chat_screen.dart';
import '../common/report_dialog.dart';
import '../notificationscreen/notification_screen.dart';
import '../user_tagging/user_model.dart';
import '../user_tagging/user_tagging_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../chatscreen/message_service.dart';
import '../chatscreen/model/models.dart';
import 'dart:math';

class InstagramHomeScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  final ValueNotifier<int>? profileRefreshNotifier;

  const InstagramHomeScreen(
      {Key? key, this.refreshNotifier, this.profileRefreshNotifier})
      : super(key: key);

  @override
  State<InstagramHomeScreen> createState() => _InstagramHomeScreenState();
}

class _InstagramHomeScreenState extends State<InstagramHomeScreen>
    with TickerProviderStateMixin {
  // Store the listener function so we can remove it later
  VoidCallback? _refreshListener;
  Map<String, int> _unreadMessageCounts = {};
  int _totalUnreadChats = 0; // Total number of users with unread messages
  RealtimeChannel? _messageSubscription;
  final UserTaggingService _taggingService = UserTaggingService();
  Map<String, List<TaggedUser>> _postTaggedUsers =
      {}; // Store tagged users per post
  late AnimationController _chatAnimationController;
  late Animation<Offset> _chatSlideAnimation;
  late Animation<Offset> _homeSlideAnimation;
  static const double _openChatThreshold = 0.5;

  late AnimationController _cameraAnimationController;
  late Animation<Offset> _cameraSlideAnimation;
  late Animation<Offset> _homeSlideAnimationForCamera;
  final double _openCameraThreshold = 0.3; // Threshold for opening camera

  // --- ADDED: Cache for isFollowingUser futures per postId ---
  final Map<String, Future<bool>> _isFollowingFutures = {};

  final ScrollController _scrollController = ScrollController();
  int _postsPerPage = 10;
  int _currentMax = 10;
  bool _isLoadingMore = false;

  // Replace the existing initState method with this:
  @override
  void initState() {
    super.initState();

    // Define the listener function
    _refreshListener = () {
      if (mounted) {
        final provider = Provider.of<InstaDataProvider>(context, listen: false);
        provider.reloadData();
      }
    };

    widget.refreshNotifier?.addListener(_refreshListener!);
    _setupMessageSubscription();
    _startListeningToUnreadMessages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTaggedUsersForAllPosts();
    });

    // Initialize AnimationController for swipe-to-chat
    _chatAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize animations for side-by-side transition
    _chatSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Chat starts off-screen to the right
      end: Offset.zero, // Chat ends fully on-screen
    ).animate(CurvedAnimation(
      parent: _chatAnimationController,
      curve: Curves.easeOut,
    ));

    _homeSlideAnimation = Tween<Offset>(
      begin: Offset.zero, // Home starts at original position
      end: const Offset(-1.0, 0.0), // Home slides completely to the left
    ).animate(CurvedAnimation(
      parent: _chatAnimationController,
      curve: Curves.easeOut,
    ));

    _cameraAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cameraSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // Slide from bottom
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cameraAnimationController,
      curve: Curves.easeInOut,
    ));
    _homeSlideAnimationForCamera = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.3, 0.0), // Slide home screen to right
    ).animate(CurvedAnimation(
      parent: _cameraAnimationController,
      curve: Curves.easeInOut,
    ));
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadTaggedUsersForAllPosts() async {
    final provider = Provider.of<InstaDataProvider>(context, listen: false);
    final posts = provider.posts;
    final suggestedPosts = provider.suggestedPosts;

    // Combine all posts
    final allPosts = [...posts, ...suggestedPosts];

    for (final post in allPosts) {
      await _loadTaggedUsersForPost(post.id);
    }
  }

  Future<void> _loadTaggedUsersForPost(String postId) async {
    try {
      final taggedUsers = await _taggingService.getTaggedUsersFromPost(postId);
      if (mounted) {
        setState(() {
          _postTaggedUsers[postId] = taggedUsers;
        });
      }
    } catch (e) {
      print('Error loading tagged users for post $postId: $e');
    }
  }

  // Add this method to listen for unread messages
  void _startListeningToUnreadMessages() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Subscribe to real-time changes in the messages table
    Supabase.instance.client
        .channel('unread_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            if (mounted) {
              await _updateUnreadMessageCounts();
            }
          },
        )
        .subscribe();

    // Initial count
    _updateUnreadMessageCounts();
  }

  void _showTaggedUsersModal(String postId) async {
    final taggedUsers = _postTaggedUsers[postId] ?? [];

    if (taggedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tagged users found')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tagged People',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: taggedUsers.length,
                itemBuilder: (context, index) {
                  final user = taggedUsers[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: user.profileImageUrl != null
                          ? CachedNetworkImageProvider(
                              _buildUserImageUrl(user.profileImageUrl!))
                          : null,
                      child: user.profileImageUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(
                      user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: user.fullName != null && user.fullName!.isNotEmpty
                        ? Text(
                            user.fullName!,
                            style: const TextStyle(color: Colors.grey),
                          )
                        : null,
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OtherUserProfileScreen(userId: user.id),
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

  // Add this method to update unread message count
  Future<void> _updateUnreadMessageCounts() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Get all unread messages grouped by sender
      final response = await Supabase.instance.client
          .from('messages')
          .select('sender_id')
          .eq('receiver_id', currentUserId)
          .eq('is_read', false)
          .neq('sender_id', currentUserId);

      // Count messages per sender
      Map<String, int> newCounts = {};
      for (final message in response) {
        final senderId = message['sender_id'] as String;
        newCounts[senderId] = (newCounts[senderId] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _unreadMessageCounts = newCounts;
          _totalUnreadChats =
              newCounts.keys.length; // Number of users with unread messages
        });
      }

      print('Unread message counts updated: $_unreadMessageCounts');
      print('Total unread chats: $_totalUnreadChats');
    } catch (e) {
      print('Error updating unread message counts: $e');
    }

    // Method to get unread count for a specific user
    int getUnreadCountForUser(String userId) {
      return _unreadMessageCounts[userId] ?? 0;
    }

    // Method to get total number of users with unread messages
    int getTotalUnreadChats() {
      return _totalUnreadChats;
    }
  }

  // Add these helper methods:
  void _openChatScreen() {
    if (_chatAnimationController.status != AnimationStatus.completed) {
      _chatAnimationController.forward();
    }
  }

  void _closeChatScreen() {
    if (_chatAnimationController.status != AnimationStatus.dismissed) {
      _chatAnimationController.reverse();
    }
  }

  // IMPORTANT: Remove the listener when the widget is disposed
  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener!);
    _messageSubscription?.unsubscribe();
    _chatAnimationController.dispose(); // Add this line
    _cameraAnimationController.dispose(); // Add this line
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';

    final difference = DateTime.now().difference(time);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(time);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _setupMessageSubscription() {
    _messageSubscription = Supabase.instance.client
        .channel('home_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Update unread counts when any message changes
            _updateUnreadMessageCounts();
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return Stack(
      children: [
        // Home Screen with slide animation (affected by both chat and camera)
        SlideTransition(
          position: _homeSlideAnimation, // This handles chat sliding
          child: SlideTransition(
            position: _homeSlideAnimationForCamera,
            // This handles camera sliding
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final screenWidth = MediaQuery.of(context).size.width;

                if (details.delta.dx > 0) {
                  // Right swipe - camera transition
                  // Reset chat animation to ensure it doesn't interfere
                  _chatAnimationController.reset();

                  final progress = (details.delta.dx / screenWidth) * 2;
                  final newValue = (_cameraAnimationController.value + progress)
                      .clamp(0.0, 1.0);
                  _cameraAnimationController.value = newValue;
                } else {
                  // Left swipe - chat transition
                  // Reset camera animation to ensure it doesn't interfere
                  _cameraAnimationController.reset();

                  final progress = (-details.delta.dx / screenWidth) * 2;
                  final newValue = (_chatAnimationController.value + progress)
                      .clamp(0.0, 1.0);
                  _chatAnimationController.value = newValue;
                }
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                final chatAnimationValue = _chatAnimationController.value;
                final cameraAnimationValue = _cameraAnimationController.value;

                if (velocity < -300 ||
                    chatAnimationValue > _openChatThreshold) {
                  // Open chat if fast swipe left or past threshold
                  _cameraAnimationController.reset(); // Ensure camera is reset
                  _chatAnimationController.forward().then((_) {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ChatScreen(
                          currentUserId: currentUserId!,
                          cameFromProfile: false,
                          onMessageRead: () {
                            _updateUnreadMessageCounts();
                          },
                        ),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration:
                            const Duration(milliseconds: 300),
                      ),
                    ).then((_) {
                      _chatAnimationController.reset();
                    });
                  });
                } else if (velocity > 300 ||
                    cameraAnimationValue > _openCameraThreshold) {
                  // Open camera if fast swipe right or past threshold
                  _chatAnimationController.reset(); // Ensure chat is reset
                  _cameraAnimationController.forward().then((_) {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            CreatePostScreen(initialTabIndex: 1),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration:
                            const Duration(milliseconds: 300),
                      ),
                    ).then((_) {
                      _cameraAnimationController.reset();
                    });
                  });
                } else {
                  // Return to home screen - reset both animations
                  _chatAnimationController.reverse();
                  _cameraAnimationController.reverse();
                }
              },
              child: Consumer<InstaDataProvider>(
                builder: (context, provider, _) {
                  // Your existing CustomScrollView content here
                  if (provider.isLoading) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!provider.isLoading) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _loadTaggedUsersForAllPosts();
                    });
                  }

                  final stories = provider.stories;
                  final posts = provider.posts;

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Your SliverAppBar and UI here as-is
                      SliverAppBar(
                        pinned: false,
                        floating: true,
                        backgroundColor: Colors.black,
                        title: Text(
                          'Instagram',
                          style: TextStyle(
                            fontFamily: 'GrandHotel',
                            fontSize: 33,
                            color: Colors.white,
                          ),
                        ),
                        actions: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => NotificationScreen()));
                            },
                            icon: Image.asset(
                              "assets/icon/Icon.png",
                              width: 25,
                              height: 25,
                            ),
                          ),
                          // Chat icon with badge
                          Stack(
                            children: [
                              IconButton(
                                onPressed: () {
                                  final currentUserId = Supabase
                                      .instance.client.auth.currentUser?.id;
                                  if (currentUserId != null) {
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation,
                                                secondaryAnimation) =>
                                            ChatScreen(
                                          currentUserId: currentUserId,
                                          cameFromProfile: false,
                                          onMessageRead: () {
                                            _updateUnreadMessageCounts();
                                          },
                                        ),
                                        transitionsBuilder: (context, animation,
                                            secondaryAnimation, child) {
                                          const begin = Offset(1.0, 0.0);
                                          const end = Offset.zero;
                                          final tween =
                                              Tween(begin: begin, end: end);
                                          final offsetAnimation =
                                              animation.drive(tween);
                                          return SlideTransition(
                                            position: offsetAnimation,
                                            child: child,
                                          );
                                        },
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'You need to be logged in to view chats.')),
                                    );
                                  }
                                },
                                icon: Image.asset(
                                    "assets/images/image-removebg-preview.png",
                                    width: 25,
                                    height: 25,
                                    color: Colors.white),
                              ),
                              if (_totalUnreadChats > 0)
                                Positioned(
                                  right: 8,
                                  top: -1,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.black, width: 1),
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      _totalUnreadChats.toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      // Stories section
                      SliverToBoxAdapter(
                        child: Container(
                          height: 121,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: stories.length,
                            itemBuilder: (context, index) {
                              final story = stories[index];
                              return _buildStoryItem(story, context);
                            },
                          ),
                        ),
                      ),
                      // Posts section
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final posts = provider.posts;
                            final suggestedPosts = provider.suggestedPosts;
                            final followingUserIds =
                                posts.map((post) => post.userId).toSet();
                            final filteredSuggestedPosts = suggestedPosts
                                .where((post) =>
                                    !followingUserIds.contains(post.userId))
                                .toList();

                            if (index < posts.length) {
                              return _buildPost(posts[index],
                                  isFollowing: true);
                            } else {
                              final suggestedIndex = index - posts.length;
                              if (suggestedIndex <
                                  filteredSuggestedPosts.length) {
                                return Column(
                                  children: [
                                    if (suggestedIndex == 0)
                                      _buildSuggestedPostsHeader(),
                                    _buildPost(
                                        filteredSuggestedPosts[suggestedIndex],
                                        isFollowing: false),
                                  ],
                                );
                              }
                            }
                            return SizedBox.shrink();
                          },
                          childCount: () {
                            final posts = provider.posts;
                            final suggestedPosts = provider.suggestedPosts;
                            final followingUserIds =
                                posts.map((post) => post.userId).toSet();
                            final filteredSuggestedPosts = suggestedPosts
                                .where((post) =>
                                    !followingUserIds.contains(post.userId))
                                .toList();
                            return posts.length + filteredSuggestedPosts.length;
                          }(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // Camera Screen overlay with slide animation
        SlideTransition(
          position: _cameraSlideAnimation,
          child: AnimatedBuilder(
            animation: _cameraAnimationController,
            builder: (context, child) {
              // Only show camera screen when animation has started
              if (_cameraAnimationController.value > 0) {
                return CreatePostScreen(initialTabIndex: 1);
              }
              return const SizedBox.shrink();
            },
          ),
        ),

        // Chat Screen overlay with slide animation
        SlideTransition(
          position: _chatSlideAnimation,
          child: AnimatedBuilder(
            animation: _chatAnimationController,
            builder: (context, child) {
              // Only show chat screen when animation has started
              if (_chatAnimationController.value > 0) {
                return ChatScreen(
                  currentUserId: currentUserId!,
                  cameFromProfile: false,
                  onMessageRead: () {
                    _updateUnreadMessageCounts();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoryItem(StoryData story, BuildContext context) {
    // No need for userStories.first, 'story' is already the aggregated object
    final String imageUrl = story.profileImageUrl ?? '';
    final bool isFullUrl = Uri.tryParse(imageUrl)?.hasAbsolutePath == true &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    final String displayUrl = isFullUrl
        ? imageUrl
        : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$imageUrl';

    final bool isMyEmptyStory = story.isMe && !story.hasStory;
    // print("🧩 Building story item -> username: ${story.username}, isMe: ${story.isMe}, hasStory: ${story.hasStory}, isMyEmptyStory: ${isMyEmptyStory}");

    return GestureDetector(
      onTap: () {
        if (isMyEmptyStory) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  CreatePostScreen(
                initialTabIndex: 1,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(-1.0, 0.0);
                const end = Offset.zero;
                final tween = Tween(begin: begin, end: end);
                final offsetAnimation = animation.drive(tween);
                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        } else {
          final provider =
              Provider.of<InstaDataProvider>(context, listen: false);

          // Get ALL stories from all users (aggregated stories)
          final allStories = provider.stories;

          // Find the current user's story index in the aggregated list
          final currentUserStoryIndex =
              allStories.indexWhere((s) => s.userId == story.userId);

          if (currentUserStoryIndex == -1) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Story not found')),
            );
            return;
          }

          // Create a list of all individual stories for ALL users in order
          List<StoryData> allIndividualStories = [];
          List<int> userStartIndices =
              []; // Track where each user's stories start

          for (int i = 0; i < allStories.length; i++) {
            final userStory = allStories[i];
            if (userStory.hasStory) {
              userStartIndices.add(allIndividualStories.length);
              final userIndividualStories =
                  provider.getIndividualStoriesForUser(userStory.userId);

              // Sort individual stories by creation time (oldest first)
              userIndividualStories.sort((a, b) {
                if (a.createdAt == null && b.createdAt == null) return 0;
                if (a.createdAt == null) return 1;
                if (b.createdAt == null) return -1;
                return a.createdAt!.compareTo(b.createdAt!);
              });

              allIndividualStories.addAll(userIndividualStories);
            }
          }

          if (allIndividualStories.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No stories found')),
            );
            return;
          }

          // Find the starting index for the current user
          int currentUserStartIndex = 0;
          for (int i = 0; i < currentUserStoryIndex; i++) {
            if (allStories[i].hasStory) {
              final userStories =
                  provider.getIndividualStoriesForUser(allStories[i].userId);
              currentUserStartIndex += userStories.length;
            }
          }

          // Find the first unviewed story for the current user
          int initialIndex = currentUserStartIndex;
          final currentUserStories =
              provider.getIndividualStoriesForUser(story.userId);

          if (!story.isViewed && currentUserStories.isNotEmpty) {
            final firstUnviewedIndex =
                currentUserStories.indexWhere((s) => !s.isViewed);
            if (firstUnviewedIndex != -1) {
              initialIndex = currentUserStartIndex + firstUnviewedIndex;
            }
          }

          // Navigate to StoryViewScreen with all stories
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryViewScreen(
                stories: allIndividualStories,
                initialIndex: initialIndex,
                userStartIndices:
                    userStartIndices, // Pass this to help with navigation
              ),
            ),
          );
        }
      },
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(left: 8, top: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stack to position the plus icon over the avatar
            Stack(
              children: [
                // Avatar with border
                Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    // Modify gradient: if it's "My Empty Story", set it to transparent.
                    // Otherwise, use the existing logic for grey/colorful borders.
                    gradient: isMyEmptyStory
                        ? const LinearGradient(
                            colors: [Colors.transparent, Colors.transparent])
                        : (story.isViewed // Use the aggregated 'isViewed'
                            ? const LinearGradient(colors: [
                                Colors.grey,
                                Colors.grey
                              ]) // All viewed
                            : const LinearGradient(colors: [
                                Colors.purple,
                                Colors.orange,
                                Colors.red
                              ])),
                    // Unviewed exists
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.black,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: CachedNetworkImageProvider(displayUrl),
                    ),
                  ),
                ),
                // Plus icon, conditionally shown when it's the current user's empty story
                if (isMyEmptyStory)
                  Positioned(
                    bottom: 2,
                    right: 8,
                    child: Container(
                      width: 22,
                      height: 23,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 80,
              child: Text(
                story.isMe ? "Your Story" : story.username,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedPostsHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Suggested posts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }

  // --- END MODIFIED _buildStoryItem METHOD ---

  Widget _buildPost(PostData post, {bool isFollowing = true}) {
    final imageUrl = (post.profileImageUrl != null &&
            post.profileImageUrl!.startsWith('http'))
        ? post.profileImageUrl!
        : post.profileImageUrl != null
            ? 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${post.profileImageUrl}'
            : 'https://your-app.com/default-avatar.png';

    // --- ADDED: Cache the isFollowingUser future for this post if not already cached ---
    final currentUser = AuthService.client().auth.currentUser;
    if (!isFollowing && currentUser != null && !_isFollowingFutures.containsKey(post.id)) {
      _isFollowingFutures[post.id] = Provider.of<InstaDataProvider>(context, listen: false)
          .isFollowingUser(currentUser.id, post.userId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: () {
              final user = AuthService.client().auth.currentUser;
              final currentUserId = user?.id;

              if (post.userId == currentUserId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          OtherUserProfileScreen(userId: post.userId)),
                );
              }
            },
            leading: CircleAvatar(
              radius: 17,
              backgroundImage: CachedNetworkImageProvider(imageUrl),
              child: imageUrl == null ? Icon(Icons.person) : null,
            ),
            title: Text(
              post.username,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: post.location != null && post.location!.isNotEmpty
                ? Text(
                    post.location!,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show follow/unfollow button for suggested posts
                if (!isFollowing) ...[
                  currentUser == null
                      ? TextButton(
                          onPressed: null,
                          child: Text('Login to follow', style: TextStyle(color: Colors.white)),
                        )
                      : FutureBuilder<bool>(
                          future: _isFollowingFutures[post.id],
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Text('Error', style: TextStyle(color: Colors.red));
                            }

                            final bool isCurrentlyFollowing = snapshot.data ?? false;

                            return TextButton(
                              onPressed: () async {
                                try {
                                  final provider = Provider.of<InstaDataProvider>(context,
                                      listen: false);
                                  final currentUserId = currentUser.id;

                                  if (isCurrentlyFollowing) {
                                    await provider.unfollowUser(
                                        currentUserId, post.userId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Unfollowed ${post.username}')),
                                    );
                                  } else {
                                    await provider.followUser(
                                        currentUserId, post.userId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Following ${post.username}')),
                                    );
                                  }
                                  // Refresh the cached future for this post
                                  setState(() {
                                    _isFollowingFutures[post.id] = provider.isFollowingUser(currentUserId, post.userId);
                                  });
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Failed to ${isCurrentlyFollowing ? 'unfollow' : 'follow'} user')),
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: isCurrentlyFollowing
                                    ? Colors.grey[800]
                                    : Colors.blue,
                                padding:
                                    EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                minimumSize: Size(0, 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                isCurrentlyFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                  SizedBox(width: 2),
                ],
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () {
                    _showPostOptions(post);
                  },
                ),
              ],
            ),
          ),
        ),
        // Rest of the post content remains the same...
        GestureDetector(
          onDoubleTap: () {
            // Only handle like action, don't interfere with image display
            Provider.of<InstaDataProvider>(context, listen: false)
                .likePost(post.id);

            // Force a rebuild by calling setState if this is a suggested post
            if (!isFollowing && mounted) {
              setState(() {});
            }
          },
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.0, // Always Instagram's 1:1 container
                child: Container(
                  color: Colors.black,
                  child: () {
                    // Parse the stored display preferences
                    final bool useOriginalRatio =
                        post.use_original_ratio ?? false;
                    final String? transformationString =
                        post.image_transformation;

                    Matrix4 transformation = Matrix4.identity();
                    if (transformationString != null &&
                        transformationString.isNotEmpty) {
                      try {
                        final values = transformationString
                            .split(',')
                            .map((e) => double.parse(e))
                            .toList();
                        if (values.length == 16) {
                          // Matrix4 has 16 values
                          transformation = Matrix4.fromList(values);
                        }
                      } catch (e) {
                        // If parsing fails, use identity matrix
                        transformation = Matrix4.identity();
                      }
                    }

                    return Transform(
                      transform: transformation,
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: useOriginalRatio ? BoxFit.contain : BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey[900],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: 0.0, // Placeholder, actual progress is handled by CachedNetworkImage
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(Icons.error, color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  }(),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 12,
                child: _hasTaggedUsers(post.id)
                    ? GestureDetector(
                        onTap: () => _showTaggedUsersModal(post.id),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Provider.of<InstaDataProvider>(context, listen: false)
                          .likePost(post.id);

                      // Force a rebuild by calling setState if this is a suggested post
                      if (!isFollowing && mounted) {
                        setState(() {});
                      }
                    },
                    child: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : Colors.white,
                      size: 27,
                    ),
                  ),
                  SizedBox(width: 3),
                  Text(
                    '${post.likeCount}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Only show comment button if comments are enabled
                  if (!post.disableComments) ...[
                    GestureDetector(
                      onTap: () {
                        showCommentSection(context, post.id);
                      },
                      child: Icon(
                        OIcons.EvaIcons.message_circle_outline,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    SizedBox(width: 3),
                    Text(
                      '${post.commentCount}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  GestureDetector(
                      onTap: () {
                        _showShareOptions(post);
                      },
                      child: Image.asset(
                        "assets/icon/shareicon.png",
                        color: Colors.white,
                        width: 25,
                        height: 25,
                      )),
                  Spacer(),
                  GestureDetector(
                    onTap: () {
                      Provider.of<InstaDataProvider>(context, listen: false)
                          .toggleSavePost(post.id);
                    },
                    child: Icon(
                      post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${post.username} ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: post.caption ?? '',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 5),
              Text(
                _formatTime(post.createdAt),
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasTaggedUsers(String postId) {
    final taggedUsers = _postTaggedUsers[postId];
    return taggedUsers != null && taggedUsers.isNotEmpty;
  }

  void _showPostOptions(PostData post) {
    final currentUser = AuthService.client().auth.currentUser;
    final currentUserId = currentUser?.id;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16, top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.save_alt, color: Colors.white),
              title: Text('Save', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Save post implementation
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.white),
              title: Text('Share', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showShareOptions(post);
              },
            ),
            if (post.userId != currentUserId)
              FutureBuilder<bool>(
                // Use FutureBuilder to check follow status asynchronously
                future: Provider.of<InstaDataProvider>(context, listen: false)
                    .isFollowingUser(currentUserId!, post.userId),
                // Ensure currentUserId is not null
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: SizedBox(
                        width: 24, // Match icon size
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      title: Text('Loading...',
                          style: TextStyle(color: Colors.white)),
                    );
                  }
                  if (snapshot.hasError) {
                    print("Error checking follow status: ${snapshot.error}");
                    return ListTile(
                      leading: const Icon(Icons.error, color: Colors.red),
                      title: const Text('Error loading follow status',
                          style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    );
                  }

                  final bool isFollowing = snapshot.data ?? false;

                  return ListTile(
                    leading: Icon(
                      isFollowing
                          ? Icons.person_remove_outlined
                          : Icons.person_add_outlined,
                      color: Colors.white,
                    ),
                    title: Text(
                      isFollowing ? 'Unfollow' : 'Follow',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context); // Close bottom sheet immediately

                      try {
                        final provider = Provider.of<InstaDataProvider>(context,
                            listen: false);
                        if (isFollowing) {
                          await provider.unfollowUser(
                              currentUserId, post.userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Unfollowed ${post.username}')),
                          );
                        } else {
                          await provider.followUser(currentUserId, post.userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Following ${post.username}')),
                          );
                        }
                        // You might want to refresh the UI that shows the follow status
                        // by calling setState in the parent widget or updating a provider.
                      } catch (e) {
                        print('Error following/unfollowing: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to ${isFollowing ? 'unfollow' : 'follow'} user')),
                        );
                      }
                    },
                  );
                },
              ),
            if (post.userId == currentUserId)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Delete Post', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  // Delete post implementation
                  try {
                    final mediaPath =
                        SupabaseService().extractMediaPath(post.imageUrl);

                    await Provider.of<InstaDataProvider>(context, listen: false)
                        .deletePost(post.id, mediaPath);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Post deleted')),
                    );
                  } catch (e) {
                    print('Delete error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete post')),
                    );
                  }
                },
              )
            else
              ListTile(
                leading: Icon(Icons.report_outlined, color: Colors.red),
                title: Text('Report', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await showDialog(
                    context: context,
                    builder: (context) =>
                        ReportDialog(targetType: 'post', targetId: post.id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Replace the existing _showShareOptions method with this implementation

  void _showShareOptions(PostData post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Share',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Divider(color: Colors.grey),

            // Users list for sharing
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getFollowingUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final user = snapshot.data![index];
                      final String imageUrl =
                          _buildUserImageUrl(user['profile_image_url']);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: user['profile_image_url'] != null
                              ? CachedNetworkImageProvider(imageUrl)
                              : null,
                          child: user['profile_image_url'] == null
                              ? Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        title: Text(
                          user['username'] ?? 'Unknown User',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: user['full_name'] != null
                            ? Text(
                                user['full_name'],
                                style: TextStyle(color: Colors.grey),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _sharePostToUser(post, user);
                        },
                      );
                    },
                  );
                },
              ),
            ),

            Divider(color: Colors.grey),

            // Add to story option
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: Colors.white),
              title: Text('Add post to your story',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _addPostToStory(post);
              },
            ),

            // Send via other methods
            ListTile(
              leading: Icon(Icons.copy, color: Colors.white),
              title: Text('Copy link', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _copyPostLink(post);
              },
            ),

            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
          ],
        ),
      ),
    );
  }

// Helper method to get following users
  Future<List<Map<String, dynamic>>> _getFollowingUsers() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      final response =
          await Supabase.instance.client.from('followers').select('''
          following_id,
          users!followers_following_id_fkey (
            id,
            username,
            full_name,
            profile_image_url
          )
        ''').eq('follower_id', currentUserId);

      return response.map<Map<String, dynamic>>((item) {
        final profile = item['users'];
        return {
          'id': profile['id'],
          'username': profile['username'],
          'full_name': profile['full_name'],
          'profile_image_url': profile['profile_image_url'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching following users: $e');
      return [];
    }
  }

// Helper method to build user image URL
  String _buildUserImageUrl(String? profileImageUrl) {
    if (profileImageUrl == null) return '';

    final bool isFullUrl =
        Uri.tryParse(profileImageUrl)?.hasAbsolutePath == true &&
            (profileImageUrl.startsWith('http://') ||
                profileImageUrl.startsWith('https://'));

    return isFullUrl
        ? profileImageUrl
        : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$profileImageUrl';
  }

// Method to share post to specific user
  void _sharePostToUser(PostData post, Map<String, dynamic> user) async {
    final currentUser = AuthService.client().auth.currentUser;
    if (currentUser == null) return;

    // Prepare shared post data (minimal for chat preview)
    final sharedPostData = {
      'post_id': post.id,
      'user_id': post.userId,
      'username': post.username,
      'profile_image_url': post.profileImageUrl,
      'image_url': post.imageUrl,
      'caption': post.caption,
    };

    // Send the message with sharedPost
    await MessageService().sendMessage(
      senderId: currentUser.id,
      receiverId: user['id'],
      sharedPost: sharedPostData,
    );

    // Optimistic UI: create a temporary Message object
    final optimisticMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      senderId: currentUser.id,
      receiverId: user['id'],
      content: null,
      imageUrl: null,
      sharedPost: sharedPostData,
      isRead: false,
      createdAt: DateTime.now(),
      seenAt: null,
    );

    // Navigate to chat with optimistic message
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: currentUser.id,
          initialChatUserId: user['id'],
          cameFromProfile: true,
          initialMessage: optimisticMessage,
        ),
      ),
    );
  }

// Method to add post to story
  void _addPostToStory(PostData post) {
    // Navigate to story creation screen with the post data
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => StoryPreviewScreen(
    //       sharedPost: post,
    //     ),
    //   ),
    // );
  }

// Method to copy post link
  void _copyPostLink(PostData post) {
    final imageUrl = post.imageUrl;
    final postLink = imageUrl.startsWith('http') && imageUrl.startsWith('https')
        ? imageUrl
        : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/post-media/${post.userId}/$imageUrl';

    Clipboard.setData(ClipboardData(text: postLink));
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) {
      _loadMorePosts();
    }
  }

  void _loadMorePosts() {
    setState(() {
      _isLoadingMore = true;
      _currentMax += _postsPerPage;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _isLoadingMore = false;
      });
    });
  }
}
