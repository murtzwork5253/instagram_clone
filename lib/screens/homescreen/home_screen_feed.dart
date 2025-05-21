import 'package:Instagram/screens/commentscreen/comment_section.dart';
import 'package:Instagram/screens/profilescreen/current_user_profile.dart';
import 'package:Instagram/screens/profilescreen/other_user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';
import '../auth/service/auth_service.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
import '../auth/login_page.dart'; // For date formatting

class InstagramHomeScreen extends StatefulWidget {
  const InstagramHomeScreen({Key? key}) : super(key: key);

  @override
  State<InstagramHomeScreen> createState() => _InstagramHomeScreenState();
}

class _InstagramHomeScreenState extends State<InstagramHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Your InstaDataProvider already loads data in its constructor
    // so we don't need to call any additional methods
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '1051202779186-kqac9ms2803rllegshdu2d3n6bjff23h.apps.googleusercontent.com', // Add this for better security
  );

  // Enhanced logout function
  Future<void> _logout() async {
    try {
      // setState(() => _isLoading = true);

      // 1. Sign out from Google
      await _googleSignIn.signOut();

      // 2. Sign out from Supabase
      await AuthService.client().auth.signOut();

      // 3. Clear any cached credentials
      // await _googleSignIn.disconnect();

      Provider.of<InstaDataProvider>(context, listen: false).reset();

      // Optional: Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {}
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
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildHomeScreen();
  }

  Widget _buildHomeScreen() {
    return Consumer<InstaDataProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        final stories = provider.stories;
        final posts = provider.posts;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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
                  onPressed: _logout,
                  icon: Icon(Icons.logout, color: Colors.white),
                ),
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
            SliverToBoxAdapter(
              child: _buildStories(stories),
            ),
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
    );
  }

  Widget _buildStories(List<StoryData> stories) {
    // Sort stories - unviewed first, then viewed
    final sortedStories = List.from(stories)
      ..sort((a, b) {
        if (a.isMe == true) return -1; // Your Story always first
        if (b.isMe == true) return 1;
        if (a.isViewed == false && b.isViewed == true) return -1;
        if (a.isViewed == true && b.isViewed == false) return 1;
        return 0;
      });

    return Container(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sortedStories.length,
        itemBuilder: (context, index) => _buildStoryItem(sortedStories[index]),
      ),
    );
  }

  Widget _buildStoryItem(StoryData story) {
    final String imageUrl = story.profileImageUrl ?? '';
    final bool isFullUrl = Uri.tryParse(imageUrl)?.hasAbsolutePath == true &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    final String displayUrl = isFullUrl
        ? imageUrl
        : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$imageUrl';

    return GestureDetector(
      onTap: () {
        // Implement story viewing logic here
        if (!story.isMe) {
          // Navigate to story view screen
          // Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewScreen(story: story)));
        } else {
          // Navigate to create story screen
          // Navigator.push(context, MaterialPageRoute(builder: (_) => CreateStoryScreen()));
        }
      },
      child: Container(
        width: 80,
        margin: EdgeInsets.only(left: 10, top: 8, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: story.isViewed || story.isMe
                    ? LinearGradient(colors: [Colors.grey, Colors.grey])
                    : LinearGradient(
                        colors: [Colors.purple, Colors.orange, Colors.red]),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Colors.black,
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey[800],
                  child: ClipOval(
                    child: Image.network(
                      displayUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 4),
            Container(
              width: 80,
              child: Text(
                story.isMe ? "Your story" : story.username,
                style: TextStyle(color: Colors.white),
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
        ListTile(
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
                MaterialPageRoute(builder: (_) => OtherUserProfileScreen(userId: post.userId)),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentSection(postId: post.id),
                        ),
                      );
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
                    child: Image.asset("assets/icon/shareicon.png", color: Colors.white, width: 25,height: 25,)
                  ),
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
                _showShareOptions(post);
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
