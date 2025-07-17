import 'package:Instagram/screens/commentscreen/comment_section.dart';
import 'package:Instagram/screens/profilescreen/current_user_profile.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';
import '../auth/service/auth_service.dart';
import '../common/report_dialog.dart';
import '../profilescreen/other_user_profile_screen.dart';
import '../user_tagging/user_model.dart';
import '../user_tagging/user_tagging_service.dart'; // Update this path if needed

class SinglePostView extends StatefulWidget {
  final List<PostData> posts; // Changed to a list
  final int initialIndex; // New parameter to know which post to start with
  final String Url; // Still needed for the profile image URL logic

  const SinglePostView({
    Key? key,
    required this.posts,
    required this.initialIndex,
    required this.Url,
  }) : super(key: key);

  @override
  State<SinglePostView> createState() => _SinglePostViewState();
}

class _SinglePostViewState extends State<SinglePostView> {
  // NEW CODE - Replace the above section with this:
  late PageController _pageController; // New: PageController to manage scrolling
  late PostData displayPost;
  late String profileUrl;
  final UserTaggingService _taggingService = UserTaggingService();
  Map<String, List<TaggedUser>> _postTaggedUsers = {}; // Store tagged users per post

  @override
  void initState() {
  super.initState();
  _loadTaggedUsersForAllPosts();
  _pageController = PageController(initialPage: widget.initialIndex); // Initialize with the starting post
  // displayPost = widget.posts[widget.initialIndex]; // Set the initial post to display

  final initialPost = widget.posts[widget.initialIndex];
  if (initialPost.profileImageUrl != null && initialPost.profileImageUrl!.startsWith('http')) {
    profileUrl = initialPost.profileImageUrl!;
  } else {
    profileUrl = 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${initialPost.profileImageUrl ?? 'default_avatar.png'}';
  }
  }

  @override
  void dispose() {
  _pageController.dispose(); // Dispose the controller when the widget is removed
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
      return 'just now';
    }
  }

  // Modify _handleLike
  void _handleLike() async {
    final provider = Provider.of<InstaDataProvider>(context, listen: false);
    final currentPostId = widget.posts[_pageController.page!.round()].id; // Get ID of the currently displayed post
    final currentPost = widget.posts[_pageController.page!.round()];

    final newLikedState = !currentPost.isLiked;
    final newLikeCount = newLikedState ? currentPost.likeCount + 1 : currentPost.likeCount - 1;

    // OPTIMISTIC UPDATE: Update the local list immediately for immediate UI feedback
    // Find the post in the widget.posts list and update it
    final postIndexInList = widget.posts.indexWhere((p) => p.id == currentPostId);
    if (postIndexInList != -1) {
      widget.posts[postIndexInList] = PostData(
        id: currentPost.id,
        userId: currentPost.userId,
        username: currentPost.username,
        profileImageUrl: currentPost.profileImageUrl,
        imageUrl: currentPost.imageUrl,
        caption: currentPost.caption,
        location: currentPost.location,
        createdAt: currentPost.createdAt,
        likeCount: newLikeCount,
        commentCount: currentPost.commentCount,
        isLiked: newLikedState,
        isSaved: currentPost.isSaved,
        disableComments: currentPost.disableComments,
        use_original_ratio: currentPost.use_original_ratio,
        image_transformation: currentPost.image_transformation,
        original_aspect_ratio: currentPost.original_aspect_ratio,
      );
      // Trigger a rebuild of the current page using setState
      setState(() {});
    }

    try {
      await provider.searchLikePost(currentPostId);
      // The provider's internal list should also be updated.
      // If `searchLikePost` already calls `updateExplorePostLike` internally,
      // and `updateExplorePostLike` calls `notifyListeners()`, then that's good.
      // However, if `widget.posts` comes from `_fetchMyProfileData` and is not the provider's `_posts` directly,
      // you need to ensure the `ProfileScreen` or `OtherUserProfileScreen`
      // also refreshes its data when a like/save occurs here.
    } catch (e) {
      print('Error liking post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like post')),
      );
      // REVERT OPTIMISTIC UPDATE on error
      if (postIndexInList != -1) {
        widget.posts[postIndexInList] = currentPost; // Revert to original state
        setState(() {}); // Revert UI
      }
    }
  }

  // Modify _handleSave (similar logic to _handleLike)
  void _handleSave() async {
    final provider = Provider.of<InstaDataProvider>(context, listen: false);
    final currentPostId = widget.posts[_pageController.page!.round()].id;
    final currentPost = widget.posts[_pageController.page!.round()];

    final newSavedState = !currentPost.isSaved;

    // OPTIMISTIC UPDATE
    final postIndexInList = widget.posts.indexWhere((p) => p.id == currentPostId);
    if (postIndexInList != -1) {
      widget.posts[postIndexInList] = PostData(
        id: currentPost.id,
        userId: currentPost.userId,
        username: currentPost.username,
        profileImageUrl: currentPost.profileImageUrl,
        imageUrl: currentPost.imageUrl,
        caption: currentPost.caption,
        location: currentPost.location,
        createdAt: currentPost.createdAt,
        likeCount: currentPost.likeCount,
        commentCount: currentPost.commentCount,
        isLiked: currentPost.isLiked,
        isSaved: newSavedState,
        disableComments: currentPost.disableComments,
        use_original_ratio: currentPost.use_original_ratio,
        image_transformation: currentPost.image_transformation,
        original_aspect_ratio: currentPost.original_aspect_ratio,
      );
      setState(() {});
    }

    try {
      await provider.toggleSavePost(currentPostId);
      // Again, ensure the provider's internal list is updated and notifies listeners.
    } catch (e) {
      print('Error saving post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save post')),
      );
      // REVERT OPTIMISTIC UPDATE on error
      if (postIndexInList != -1) {
        widget.posts[postIndexInList] = currentPost; // Revert to original state
        setState(() {}); // Revert UI
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUserId = AuthService.client().auth.currentUser?.id;

    // // This checks if the provider has a more up-to-date version of the post
    // // This is useful if the post is from the main feed and was updated in the background
    // // NEW CODE - Replace the above section with this:
    // final provider = Provider.of<InstaDataProvider>(context);
    // try {
    //   final providerVersion = provider.posts.firstWhere((p) => p.id == displayPost.id); // Use displayPost.id
    //   // If the provider's version is different from our local state, update our local state
    //   if (providerVersion.isLiked != displayPost.isLiked || providerVersion.isSaved != displayPost.isSaved) {
    //     // Only update if current displayPost is the one from providerVersion,
    //     // to avoid state issues when scrolling rapidly.
    //     if (providerVersion.id == displayPost.id) {
    //       displayPost = providerVersion;
    //     }
    //   }
    // } catch (e) {
    //   // Post is not in the main feed, which is expected for explore posts.
    // }


    // NEW CODE - Replace the above section with this:
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(loc.post, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder( // Changed to PageView.builder
        controller: _pageController,
        scrollDirection: Axis.vertical, // Enable vertical scrolling
        itemCount: widget.posts.length, // Number of posts to display
        onPageChanged: (index) {
          setState(() {
            displayPost = widget.posts[index]; // Update displayPost when page changes
            // You might also need to update profileUrl if it varies per post,
            // or pass it directly into the post item builder.
            // For now, assuming profileUrl is consistent for all posts in this list,
            // or derived from displayPost.profileImageUrl.
          });
        },
        itemBuilder: (context, index) {
          final post = widget.posts[index]; // Get the current post for this page
          final currentProfileUrl = post.profileImageUrl!.startsWith('http')
              ? post.profileImageUrl
              : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${post.profileImageUrl}';

          return SingleChildScrollView( // Each page can still scroll if its content is long
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(currentProfileUrl!), // Use currentProfileUrl
                    radius: 16,
                  ),
                  title: GestureDetector(
                    onTap: () {
                      if (post.userId == currentUserId) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileScreen(userId: post.userId)));
                      }
                    },
                    child: Text(
                      post.username,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  trailing: IconButton(onPressed: () { _showPostOptions(post, context);}, icon: Icon(Icons.more_vert, color: Colors.white)),
                ),
                GestureDetector(
                  onDoubleTap: _handleLike,
                  child: Stack(
                    children:[
                      AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
                        color: Colors.black,
                        child: () {
                          final bool useOriginalRatio = post.use_original_ratio ?? false;
                          final String? transformationString = post.image_transformation;

                          Matrix4 transformation = Matrix4.identity();
                          if (transformationString != null && transformationString.isNotEmpty) {
                            try {
                              final values = transformationString.split(',').map((e) => double.parse(e)).toList();
                              if (values.length == 16) {
                                transformation = Matrix4.fromList(values);
                              }
                            } catch (e) {
                              transformation = Matrix4.identity();
                            }
                          }

                          return Transform(
                            transform: transformation,
                            child: Image.network(
                              post.imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: useOriginalRatio ? BoxFit.contain : BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.grey[900],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.grey[900],
                                  child: const Center(
                                    child: Icon(Icons.error, color: Colors.white),
                                  ),
                                );
                              },
                            ),
                          );
                        }(),
                      ),
                    ),
                      Positioned(
                        bottom:10,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _handleLike,
                            child: Icon(
                              post.isLiked ? Icons.favorite : Icons.favorite_border,
                              color: post.isLiked ? Colors.red : Colors.white,
                              size: 27,
                            ),
                          ),
                          SizedBox(width: 3),
                          Text('${post.likeCount}', style: TextStyle(color: Colors.white)),
                          SizedBox(width: 12),
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
                            Text('${post.commentCount}', style: TextStyle(color: Colors.white)),
                            SizedBox(width: 12),
                          ],
                          GestureDetector(
                              onTap: () {
                                _showShareOptions(post, context);
                              },
                              child: Image.asset("assets/icon/shareicon.png", color: Colors.white, width: 26, height: 26)),
                          Spacer(),
                          GestureDetector(
                            onTap: _handleSave,
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
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _hasTaggedUsers(String postId) {
    final taggedUsers = _postTaggedUsers[postId];
    return taggedUsers != null && taggedUsers.isNotEmpty;
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
                          ? NetworkImage(_buildUserImageUrl(user.profileImageUrl!))
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

  void _showPostOptions(PostData post,BuildContext context) {
    final currentUser = AuthService.client().auth.currentUser;
    final currentUserId = currentUser?.id;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom+16,top: 12),
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
                _showShareOptions(post,context);
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
                          await provider.unfollowUser(currentUserId!, post.userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unfollowed ${post.username}')),
                          );
                        } else {
                          await provider.followUser(currentUserId!, post.userId);
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
                onTap: () async{
                  Navigator.pop(context);
                  // Delete post implementation
                  try {
                    final mediaPath = SupabaseService().extractMediaPath(post.imageUrl);

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
                onTap: () async{
                  Navigator.pop(context);
                  await showDialog(
                    context: context,
                    builder: (context) => ReportDialog(targetType: 'post', targetId: post.id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions(PostData post,BuildContext context) {
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
