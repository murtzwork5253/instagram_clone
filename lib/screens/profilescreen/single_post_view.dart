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
    late final String profileUrl;
    if (Url.isNotEmpty && Url.startsWith('http')){
      profileUrl = Url;
    }else{
      profileUrl='https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${Url}';
    }

    return Consumer<InstaDataProvider>(
      builder: (context, provider, _) {
        final updatedPost = provider.posts.firstWhere(
              (p) => p.id == post.id,
          orElse: () => post,
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileScreen()),
                      );
                    },
                    child: Text(
                      updatedPost.username,
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
                        .likePost(updatedPost.id);
                  },
                  child: Image.network(
                    updatedPost.imageUrl,
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Provider.of<InstaDataProvider>(context,
                                  listen: false)
                                  .likePost(updatedPost.id);
                            },
                            child: Icon(
                              updatedPost.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: updatedPost.isLiked
                                  ? Colors.red
                                  : Colors.white,
                              size: 27,
                            ),
                          ),
                          SizedBox(width: 3),
                          Text('${updatedPost.likeCount}',
                              style: TextStyle(color: Colors.white)),
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
                          Text('${updatedPost.commentCount}',
                              style: TextStyle(color: Colors.white)),
                          SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              // Navigate to comments screen
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
                              text: '${updatedPost.username} ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            TextSpan(
                              text: updatedPost.caption ?? '',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        _formatTime(updatedPost.createdAt),
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
            ListTile(
              leading: Icon(Icons.person_add_outlined, color: Colors.white),
              title: Text('Follow', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Follow user implementation
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
