import 'package:Instagram/screens/commentscreen/comment_section.dart';
import 'package:Instagram/screens/profilescreen/current_user_profile.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';
import '../auth/service/auth_service.dart';
import '../common/report_dialog.dart';
import '../profilescreen/other_user_profile_screen.dart'; // Update this path if needed

// NEW CODE - Replace the above section with this:
class SinglePostView extends StatefulWidget {
  final PostData post;
  final String Url;

  const SinglePostView({Key? key, required this.post, required this.Url}) : super(key: key);

  @override
  State<SinglePostView> createState() => _SinglePostViewState();
}

class _SinglePostViewState extends State<SinglePostView> {
  late PostData displayPost;
  late String profileUrl;

  @override
  void initState() {
    super.initState();
    displayPost = widget.post;

    if (widget.Url.isNotEmpty && widget.Url.startsWith('http')) {
      profileUrl = widget.Url;
    } else {
      profileUrl = 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${widget.Url}';
    }
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

  void _handleLike() async {
    final provider = Provider.of<InstaDataProvider>(context, listen: false);
    final newLikedState = !displayPost.isLiked;
    final newLikeCount = newLikedState ? displayPost.likeCount + 1: displayPost.likeCount - 1;

    setState(() {
      displayPost = PostData(
          id: displayPost.id,
          userId: displayPost.userId,
          username: displayPost.username,
          profileImageUrl: displayPost.profileImageUrl,
          imageUrl: displayPost.imageUrl,
          caption: displayPost.caption,
          location: displayPost.location,
          createdAt: displayPost.createdAt,
          likeCount: newLikeCount,
          commentCount: displayPost.commentCount,
          isLiked: newLikedState,
          isSaved: displayPost.isSaved,
          disableComments: displayPost.disableComments,
          use_original_ratio: displayPost.use_original_ratio,
          image_transformation: displayPost.image_transformation,
          original_aspect_ratio: displayPost.original_aspect_ratio);
    });

    try {
      await provider.searchLikePost(displayPost.id);
      provider.updateExplorePostLike(displayPost.id, newLikedState);
    } catch (e) {
      print('Error liking post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like post')),
      );
      setState(() {
        displayPost = widget.post;
      });
    }
  }

  void _handleSave() async {
    final provider = Provider.of<InstaDataProvider>(context, listen: false);
    final newSavedState = !displayPost.isSaved;

    setState(() {
      displayPost = PostData(
          id: displayPost.id,
          userId: displayPost.userId,
          username: displayPost.username,
          profileImageUrl: displayPost.profileImageUrl,
          imageUrl: displayPost.imageUrl,
          caption: displayPost.caption,
          location: displayPost.location,
          createdAt: displayPost.createdAt,
          likeCount: displayPost.likeCount,
          commentCount: displayPost.commentCount,
          isLiked: displayPost.isLiked,
          isSaved: newSavedState,
          disableComments: displayPost.disableComments,
          use_original_ratio: displayPost.use_original_ratio,
          image_transformation: displayPost.image_transformation,
          original_aspect_ratio: displayPost.original_aspect_ratio);
    });

    try {
      await provider.toggleSavePost(displayPost.id);
      provider.updateExplorePostSave(displayPost.id, newSavedState);
    } catch (e) {
      print('Error saving post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save post')),
      );
      setState(() {
        displayPost = widget.post;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUserId = AuthService.client().auth.currentUser?.id;

    // This checks if the provider has a more up-to-date version of the post
    // This is useful if the post is from the main feed and was updated in the background
    final provider = Provider.of<InstaDataProvider>(context);
    try {
      final providerVersion = provider.posts.firstWhere((p) => p.id == widget.post.id);
      // If the provider's version is different from our local state, update our local state
      if (providerVersion.isLiked != displayPost.isLiked || providerVersion.isSaved != displayPost.isSaved) {
        displayPost = providerVersion;
      }
    } catch (e) {
      // Post is not in the main feed, which is expected for explore posts.
    }


    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(loc.post, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profileUrl),
                radius: 16,
              ),
              title: GestureDetector(
                onTap: () {
                  if (displayPost.userId == currentUserId) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileScreen(userId: displayPost.userId)));
                  }
                },
                child: Text(
                  displayPost.username,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              trailing: IconButton(onPressed: () { _showPostOptions(displayPost, context);}, icon: Icon(Icons.more_vert, color: Colors.white)),
            ),
            GestureDetector(
              onDoubleTap: _handleLike,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  color: Colors.black,
                  child: () {
                    final bool useOriginalRatio = displayPost.use_original_ratio ?? false;
                    final String? transformationString = displayPost.image_transformation;

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
                        displayPost.imageUrl,
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
                          displayPost.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: displayPost.isLiked ? Colors.red : Colors.white,
                          size: 27,
                        ),
                      ),
                      SizedBox(width: 3),
                      Text('${displayPost.likeCount}', style: TextStyle(color: Colors.white)),
                      SizedBox(width: 12),
                      if (!displayPost.disableComments) ...[
                        GestureDetector(
                          onTap: () {
                            showCommentSection(context, displayPost.id);
                          },
                          child: Icon(
                            OIcons.EvaIcons.message_circle_outline,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                        SizedBox(width: 3),
                        Text('${displayPost.commentCount}', style: TextStyle(color: Colors.white)),
                        SizedBox(width: 12),
                      ],
                      GestureDetector(
                          onTap: () {
                            _showShareOptions(displayPost, context);
                          },
                          child: Image.asset("assets/icon/shareicon.png", color: Colors.white, width: 26, height: 26)),
                      Spacer(),
                      GestureDetector(
                        onTap: _handleSave,
                        child: Icon(
                          displayPost.isSaved ? Icons.bookmark : Icons.bookmark_border,
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
                          text: '${displayPost.username} ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextSpan(
                          text: displayPost.caption ?? '',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    _formatTime(displayPost.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
