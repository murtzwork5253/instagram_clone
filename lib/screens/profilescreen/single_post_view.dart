import 'package:Instagram/screens/commentscreen/comment_section.dart';
import 'package:Instagram/screens/profilescreen/current_user_profile.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';
import '../auth/service/auth_service.dart';
import '../profilescreen/other_user_profile_screen.dart'; // Update this path if needed

class SinglePostView extends StatelessWidget {
  final PostData post;
  final String Url;

  const SinglePostView({Key? key, required this.post, required this.Url}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final user = AuthService.client().auth.currentUser;
    final currentUserId = user?.id;
    late final String profileUrl;
    if (Url.isNotEmpty && Url.startsWith('http')){
      profileUrl = Url;
    }else{
      profileUrl='https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${Url}';
    }

    // Replace the Consumer<InstaDataProvider> section in single_post_view.dart (around line 46-60) with this:

    return Consumer<InstaDataProvider>(
      builder: (context, provider, _) {
        // Try to get updated post from provider, but fallback to original post if not found
        PostData updatedPost;
        try {
          updatedPost = provider.posts.firstWhere((p) => p.id == post.id);
        } catch (e) {
          // If post not found in provider, use the original post passed from explore screen
          updatedPost = post;
        }

        // For explore posts, ensure we show the original counts if provider doesn't have updated data
        final displayPost = PostData(
          id: updatedPost.id,
          userId: updatedPost.userId,
          username: updatedPost.username,
          profileImageUrl: updatedPost.profileImageUrl,
          imageUrl: updatedPost.imageUrl,
          caption: updatedPost.caption,
          location: updatedPost.location,
          createdAt: updatedPost.createdAt,
          // Use provider counts if available and greater than 0, otherwise use original
          likeCount: (updatedPost.likeCount > 0 || post.likeCount == 0)
              ? updatedPost.likeCount
              : post.likeCount,
          commentCount: (updatedPost.commentCount > 0 || post.commentCount == 0)
              ? updatedPost.commentCount
              : post.commentCount,
          isLiked: updatedPost.isLiked,
        );

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text('Post', style: TextStyle(color: Colors.white)),
            iconTheme: IconThemeData(color: Colors.white),
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
                      if(post.userId == currentUserId){
                        Navigator.push(context, MaterialPageRoute(builder: (_)=> ProfileScreen()));
                      }
                      else{
                        Navigator.push(context, MaterialPageRoute(builder: (_)=> OtherUserProfileScreen(userId: post.userId)));
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
                  trailing: IconButton(onPressed: (){_showPostOptions(post, context);}, icon: Icon(Icons.more_vert, color: Colors.white)),
                ),
                GestureDetector(
                  onDoubleTap: () {
                    Provider.of<InstaDataProvider>(context, listen: false)
                        .likePost(displayPost.id);
                  },
                  child: Image.network(
                    displayPost.imageUrl,
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width,
                    fit: BoxFit.cover,
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
                            onTap: () {
                              Provider.of<InstaDataProvider>(context, listen: false)
                                  .likePost(displayPost.id);
                            },
                            child: Icon(
                              displayPost.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: displayPost.isLiked
                                  ? Colors.red
                                  : Colors.white,
                              size: 27,
                            ),
                          ),
                          SizedBox(width: 3),
                          Text('${displayPost.likeCount}',
                              style: TextStyle(color: Colors.white)),
                          SizedBox(width: 12),
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
                          Text('${displayPost.commentCount}',
                              style: TextStyle(color: Colors.white)),
                          SizedBox(width: 12),
                          GestureDetector(
                              onTap: () {
                                _showShareOptions(post,context);
                              },
                              child: Image.asset("assets/icon/shareicon.png",color: Colors.white,width: 26,height: 26,)
                          ),
                          Spacer(),
                          Icon(Icons.bookmark_border,
                              color: Colors.white, size: 27),
                        ],
                      ),
                      SizedBox(height: 10),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${displayPost.username} ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
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
                        style: TextStyle(color: Colors.grey, fontSize: 12),
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
