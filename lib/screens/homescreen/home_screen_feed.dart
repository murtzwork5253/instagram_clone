import 'package:Instagram/screens/commentscreen/comment_section.dart';
import 'package:Instagram/screens/createscreens/create_post/create_post_screen.dart';
import 'package:Instagram/screens/homescreen/story_view_screen.dart';
import 'package:Instagram/screens/profilescreen/current_user_profile.dart';
import 'package:Instagram/screens/profilescreen/other_user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';
import '../auth/service/auth_service.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
import '../createscreens/create_story/create_story_screen.dart'; // For date formatting

class InstagramHomeScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  final ValueNotifier<int>? profileRefreshNotifier;

  const InstagramHomeScreen({Key? key, this.refreshNotifier, this.profileRefreshNotifier}) : super(key: key);

  @override
  State<InstagramHomeScreen> createState() => _InstagramHomeScreenState();
}

class _InstagramHomeScreenState extends State<InstagramHomeScreen> {

  // Store the listener function so we can remove it later
  VoidCallback? _refreshListener;

  void initState() {
    super.initState();

    // Define the listener function
    _refreshListener = () {
      // Always check if the widget is still mounted before using context
      if (mounted) {
        final provider = Provider.of<InstaDataProvider>(context, listen: false);
        provider.reloadData();
      }
    };

    // Add the listener
    widget.refreshNotifier?.addListener(_refreshListener!);
  }

  // IMPORTANT: Remove the listener when the widget is disposed
  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener!);
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Detect a horizontal drag ending, specifically a swipe from left to right.
      onHorizontalDragEnd: (details) {
        // Check if the primary velocity is positive (indicating a swipe from left to right)
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          // Push the CreateStoryContent screen as a full-screen modal dialog.
          // This will overlay the story screen on top of the home feed without
          // directly altering the home feed's AppBar or BottomNavigationBar.
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  CreatePostScreen(initialTabIndex: 1,),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const beginOffset = Offset(-1.0, 0.0); // CreateStoryContent starts from left
                const endOffset = Offset.zero;

                const homeScreenBeginOffset = Offset.zero;
                const homeScreenEndOffset = Offset(0.3, 0.0); // Home screen slides slightly to the right

                // Tween for the incoming CreateStoryContent
                var storyScreenTween = Tween(begin: beginOffset, end: endOffset).chain(CurveTween(curve: Curves.ease));

                // Tween for the outgoing HomeScreen (current context)
                var homeScreenTween = Tween(begin: homeScreenBeginOffset, end: homeScreenEndOffset).chain(CurveTween(curve: Curves.ease));


                return Stack(
                  children: <Widget>[
                    // The current route (HomeScreen) animates out slightly
                    SlideTransition(
                      position: homeScreenTween.animate(animation), // Use the main animation for the home screen
                      child: this.widget, // Refers to the current widget, which is the HomeScreen
                    ),
                    // The new route (CreateStoryContent) animates in
                    SlideTransition(
                      position: storyScreenTween.animate(animation),
                      child: child, // The child is CreateStoryContent
                    ),
                  ],
                );
              },
              fullscreenDialog: true, // Optional: still makes it feel like a modal
            ),
          );
        }
      },
      child: Consumer<InstaDataProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator());
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
                  IconButton(onPressed: (){}, icon: Image.asset("assets/icon/Icon.png",width: 25,height: 25,)),
                  IconButton(
                    onPressed: () {},
                    icon: Image.asset(
                      "assets/images/image-removebg-preview.png",
                      width: 25,
                      height: 25,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // --- MODIFIED STORIES SECTION ---
              SliverToBoxAdapter(
                child: Container(
                  height: 110, // Fixed height for story row
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.length, // Iterate over the aggregated stories
                    itemBuilder: (context, index) {
                      final story = stories[index]; // 'story' is a single aggregated StoryData object
                      return _buildStoryItem(story, context); // Pass the single aggregated StoryData
                    },
                  ),
                ),
              ),
              // --- END MODIFIED STORIES SECTION ---
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPost(posts[index]),
                  childCount: posts.length,
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 10)),
            ],
          );
        },
      ),
    );
  }

  // Widget _buildStories(List<StoryData> stories) {
  //   // Group all stories by userId
  //   final Map<String, List<StoryData>> groupedStories = {};
  //
  //
  //   for (final story in stories) {
  //     groupedStories.putIfAbsent(story.userId, () => []).add(story);
  //   }
  //
  //   // Convert grouped values into a list
  //   final List<List<StoryData>> groupedList = groupedStories.values.toList();
  //
  //
  //   // Sort user groups: isMe first, then unviewed, then viewed
  //   groupedList.sort((a, b) {
  //     final storyA = a.first;
  //     final storyB = b.first;
  //
  //     if (storyA.isMe) return -1;
  //     if (storyB.isMe) return 1;
  //     if (!storyA.isViewed && storyB.isViewed) return -1;
  //     if (storyA.isViewed && !storyB.isViewed) return 1;
  //     return 0;
  //   });
  //
  //   return Container(
  //     height: 110,
  //     child: ListView.builder(
  //       scrollDirection: Axis.horizontal,
  //       itemCount: groupedList.length,
  //       itemBuilder: (context, index) {
  //         final userStories = groupedList[index];
  //         return _buildStoryItem(userStories);
  //       },
  //     ),
  //   );
  // }

  // --- MODIFIED _buildStoryItem METHOD ---
  // Now accepts a single StoryData object (the aggregated one)
  Widget _buildStoryItem(StoryData story, BuildContext context) {
    // No need for userStories.first, 'story' is already the aggregated object
    final String imageUrl = story.profileImageUrl ?? '';
    final bool isFullUrl = Uri.tryParse(imageUrl)?.hasAbsolutePath == true &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    final String displayUrl = isFullUrl
        ? imageUrl
        : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$imageUrl';

    final bool isMyEmptyStory = story.isMe && !story.hasStory;
    print("🧩 Building story item -> username: ${story.username}, isMe: ${story.isMe}, hasStory: ${story.hasStory}, isMyEmptyStory: ${isMyEmptyStory}");


    return GestureDetector(
      onTap: () {
        if (isMyEmptyStory) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  CreateStoryContent(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        }
        else {
          final provider = Provider.of<InstaDataProvider>(context, listen: false);

          // Get all individual stories for this user from the provider's dedicated map
          final List<StoryData> userAllIndividualStories = provider.getIndividualStoriesForUser(story.userId);

          // Sort stories for display order in StoryViewScreen (oldest first)
          userAllIndividualStories.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return a.createdAt!.compareTo(b.createdAt!);
          });

          // NEW LOGIC: Find the initial index of the first unviewed story
          int initialIndex = 0; // Default to the first story
          if (!story.isViewed) { // Only search for unviewed if the aggregated story is not viewed
            final firstUnviewedIndex = userAllIndividualStories.indexWhere((s) => !s.isViewed);
            if (firstUnviewedIndex != -1) {
              initialIndex = firstUnviewedIndex;
            }
          }


          if (userAllIndividualStories.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoryViewScreen(
                  stories: userAllIndividualStories, // Pass the list of ALL individual stories
                  initialIndex: initialIndex, // Pass the calculated initial index
                ),
              ),
            );
          } else {
            // Handle case where no individual stories are found, even if aggregated had 'hasStory'
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No individual stories found for ${story.username}')),
            );
          }
        }
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(left: 10, top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stack to position the plus icon over the avatar
            Stack(
              children: [
                // Avatar with border
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    // Modify gradient: if it's "My Empty Story", set it to transparent.
                    // Otherwise, use the existing logic for grey/colorful borders.
                    gradient: isMyEmptyStory
                        ? const LinearGradient(colors: [Colors.transparent, Colors.transparent])
                        : (story.isViewed // Use the aggregated 'isViewed'
                        ? const LinearGradient(colors: [Colors.grey, Colors.grey]) // All viewed
                        : const LinearGradient(colors: [Colors.purple, Colors.orange, Colors.red])), // Unviewed exists
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.black,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: NetworkImage(displayUrl),
                    ),
                  ),
                ),
                // Plus icon, conditionally shown when it's the current user's empty story
                if (isMyEmptyStory)
                  Positioned(
                    bottom: 0,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 16,
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
  // --- END MODIFIED _buildStoryItem METHOD ---

  Widget _buildPost(PostData post) {
    final imageUrl = (post.profileImageUrl != null &&
            post.profileImageUrl!.startsWith('http'))
        ? post.profileImageUrl!
        : post.profileImageUrl != null
            ? 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${post.profileImageUrl}'
            : 'https://your-app.com/default-avatar.png'; // <-- Replace with your fallback avatar

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
                // Navigate to current user's profile
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                );
              } else {
                // Navigate to other user's profile
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          OtherUserProfileScreen(userId: post.userId)),
                );
              }
            },
            leading: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(
                imageUrl,
              ),
            ),
            title: Text(
              post.username,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: post.location != null && post.location!.isNotEmpty
                ? Text(
                    post.location!,
                    style: TextStyle(color: Colors.white),
                  )
                : null,
            trailing: IconButton(
              icon: Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                // Show post options
                _showPostOptions(post);
              },
            ),
          ),
        ),
        GestureDetector(
          onDoubleTap: () {
            // Like post on double tap
            Provider.of<InstaDataProvider>(context, listen: false)
                .likePost(post.id);
          },
          child: Image.network(
            post.imageUrl,
            width: double.infinity,
            height: MediaQuery.of(context).size.width,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.width,
                color: Colors.grey[900],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.width,
                color: Colors.grey[900],
                child: Center(
                  child: Icon(Icons.error, color: Colors.white),
                ),
              );
            },
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
                      // Toggle like
                      Provider.of<InstaDataProvider>(context, listen: false)
                          .likePost(post.id);
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
                  GestureDetector(
                    onTap: () {
                      // Navigate to comments screen
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
                  GestureDetector(
                      onTap: () {
                        // Show share options
                        _showShareOptions(post);
                      },
                      child: Image.asset(
                        "assets/icon/shareicon.png",
                        color: Colors.white,
                        width: 25,
                        height: 25,
                      )),
                  Spacer(),
                  Icon(
                    Icons.bookmark_border,
                    color: Colors.white,
                    size: 27,
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
                    .isFollowingUser(currentUserId!, post.userId), // Ensure currentUserId is not null
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: SizedBox(
                        width: 24, // Match icon size
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      title: Text('Loading...', style: TextStyle(color: Colors.white)),
                    );
                  }
                  if (snapshot.hasError) {
                    print("Error checking follow status: ${snapshot.error}");
                    return ListTile(
                      leading: const Icon(Icons.error, color: Colors.red),
                      title: const Text('Error loading follow status', style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    );
                  }

                  final bool isFollowing = snapshot.data ?? false;

                  return ListTile(
                    leading: Icon(
                      isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined,
                      color: Colors.white,
                    ),
                    title: Text(
                      isFollowing ? 'Unfollow' : 'Follow',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context); // Close bottom sheet immediately

                      try {
                        final provider = Provider.of<InstaDataProvider>(context, listen: false);
                        if (isFollowing) {
                          await provider.unfollowUser(currentUserId, post.userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unfollowed ${post.username}')),
                          );
                        } else {
                          await provider.followUser(currentUserId, post.userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Following ${post.username}')),
                          );
                        }
                        // You might want to refresh the UI that shows the follow status
                        // by calling setState in the parent widget or updating a provider.
                      } catch (e) {
                        print('Error following/unfollowing: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to ${isFollowing ? 'unfollow' : 'follow'} user')),
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
                onTap: () {
                  Navigator.pop(context);
                  // Report post implementation
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions(PostData post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Share',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Divider(color: Colors.grey),
          Container(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              children: List.generate(
                8,
                (index) => Container(
                  width: 70,
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[800],
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'User ${index + 1}',
                        style: TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(color: Colors.grey),
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: Colors.white),
            title: Text('Add post to your story',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // Add to story implementation
            },
          ),
          ListTile(
            leading: Icon(Icons.send, color: Colors.white),
            title: Text('Send post', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // Send post implementation
            },
          ),
        ],
      ),
    );
  }
}
