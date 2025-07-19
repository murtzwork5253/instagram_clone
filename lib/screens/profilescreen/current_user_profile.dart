import 'package:Instagram/screens/createscreens/create_post/create_post_screen.dart';
import 'package:Instagram/screens/profilescreen/profile_settings_menu.dart';
import 'package:Instagram/screens/profilescreen/single_post_view.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_localizations.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';
import 'edit_profile_screen.dart';
import 'followers_following_screen.dart';
import '../../services/blocked_users_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;

  const ProfileScreen({Key? key, this.refreshNotifier}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  VoidCallback? _refreshListener;
  String? _cacheKey;

  void initState() {
    super.initState();

    _cacheKey = DateTime.now().millisecondsSinceEpoch.toString();

    // Create a separate listener function
    _refreshListener = () {
      if (mounted) {
        // Update cache key to force FutureBuilder to rebuild
        _cacheKey = DateTime.now().millisecondsSinceEpoch.toString();

        // Reload profile-specific data in provider (if needed)
        final provider = Provider.of<InstaDataProvider>(context, listen: false);
        provider.reloadProfileData(); // Use the new profile-specific method

        // Trigger setState to refresh FutureBuilder
        setState(() {});
      }
    };

    // Add the listener
    widget.refreshNotifier?.addListener(_refreshListener!);
  }

  @override
  void dispose() {
    // Remove the listener to prevent memory leaks
    if (_refreshListener != null) {
      widget.refreshNotifier?.removeListener(_refreshListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildProfileScreen();
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Widget _buildProfileScreen() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final loc = AppLocalizations.of(context)!;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            loc.errorLoadingProfile,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Use cache key to force fresh data fetch
    final futureKey = '${user.id}_$_cacheKey';

    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(futureKey), // This forces rebuild when cache key changes
      future: _fetchMyProfileData(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              loc.errorLoadingProfile,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Text(
              loc.noProfileData,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final data = snapshot.data!;
        final profile = data['users'] ?? {};
        final posts = data['posts'] ?? [];
        final followers = data['followers'] ?? [];
        final following = data['following'] ?? [];

        String? avatarUrl;
        late final String imageUrl;
        if (profile['profile_image_url'] != null) {
          imageUrl = profile['profile_image_url'];
          avatarUrl = imageUrl.toString().startsWith('http')
              ? imageUrl
              : supabase.storage.from('avatars').getPublicUrl(imageUrl);
        }
        else{
          imageUrl = "";
          avatarUrl = null;
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.white, size: 20), // Lock icon
                const SizedBox(width: 8), // Spacing between icon and text
                Text(
                  profile['username'] ?? 'Profile',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              IconButton(
                  onPressed: () {
                    showCreateSection(context);
                  },
                  icon: Image.asset("assets/icon/add_post_icon.png",color: Colors.white,width: 21,)),
              IconButton(
                  onPressed: () {
                    Navigator.of(context).push(PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const ProfileMenuScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
                          const end =
                              Offset.zero; // Ends at its normal position
                          const curve = Curves.ease;

                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));

                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                        fullscreenDialog: false));
                  },
                  icon: const Icon(Icons.menu, color: Colors.white),iconSize: 28,),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            color: Colors.white,
            backgroundColor: Colors.black,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatarSection(avatarUrl, profile),
                        const SizedBox(width: 14), // Spacing between story and name/stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Removed the extra Padding(left: 28) here to allow the name to align
                              // more naturally with the stats below it after removing the avatar.
                              // You might need to adjust this padding based on your exact design.
                              Text(profile['full_name'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 14),
                              _buildStatsSection(posts.length, followers.length,
                                  following.length),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildBioSection(profile),
                  ),
                  const SizedBox(height: 12),
                  _buildActionButtons(),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, thickness: 0.2),
                  _buildPostTabs(posts, imageUrl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsSection(int postCount, int followers, int following) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(loc.posts, postCount),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowersList(
                  userId: Supabase.instance.client.auth.currentUser!.id,
                  isFollowersTab: true,
                ),
              ),
            );
          },
          child: _buildStatItem(loc.followers, followers),
        ),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowersList(
                  userId: Supabase.instance.client.auth.currentUser!.id,
                  isFollowersTab: false,
                ),
              ),
            );
          },
          child: _buildStatItem(loc.following, following),
        ),
      ],
    );
  }

  // Also, add error handling to your main fetch method:
  Future<Map<String, dynamic>> _fetchMyProfileData(String userId) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      // Session/user is not available, return empty data
      return {
        'users': {},
        'posts': <PostData>[],
        'followers': [],
        'following': [],
      };
    }
    final currentUserId = currentUser.id;

    try {
      // Fetch user profile data
      final profileRes = await supabase.from('users').select().eq('id', userId).single();

      // Fetch posts with associated user data
      final postsResponse = await supabase
          .from('posts')
          .select('''
          id,
          user_id,
          caption,
          location,
          image_url,
          created_at,
          disable_comments,
          use_original_ratio,
          image_transformation,
          original_aspect_ratio,
          users (
            username,
            profile_image_url
          )
        ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Get all post IDs from the fetched posts
      final postIds = (postsResponse as List).map((post) => post['id']).toList();

      // Fetch all likes for these posts
      final likesResponse = await supabase
          .from('post_likes')
          .select('post_id, user_id')
          .inFilter('post_id', postIds);

      // Fetch all comments for these posts
      final commentsResponse = await supabase
          .from('comments')
          .select('id, post_id')
          .inFilter('post_id', postIds);

      // Fetch saved posts for the current user
      List<dynamic> savedResponse = [];
      if (currentUserId != null) {
        savedResponse = await supabase
            .from('saved_posts')
            .select('post_id')
            .eq('user_id', currentUserId)
            .inFilter('post_id', postIds);
      }

      // Group likes, comments, and saves by post_id for easier lookup
      final Map<String, List<dynamic>> likesByPost = {};
      final Map<String, List<dynamic>> commentsByPost = {};
      final Set<String> savedPostIds = savedResponse.map((save) => save['post_id'].toString()).toSet();

      for (final like in likesResponse as List) {
        final postId = like['post_id'].toString();
        likesByPost[postId] = (likesByPost[postId] ?? [])..add(like);
      }

      for (final comment in commentsResponse as List) {
        final postId = comment['post_id'].toString();
        commentsByPost[postId] = (commentsByPost[postId] ?? [])..add(comment);
      }

      // Map raw post data to PostData objects
      final List<PostData> fetchedPosts = (postsResponse).map((post) {
        final user = post['users'];
        final postId = post['id'].toString();
        final likes = likesByPost[postId] ?? [];
        final comments = commentsByPost[postId] ?? [];

        final bool isLiked = currentUserId != null
            ? likes.any((like) => like['user_id'] == currentUserId)
            : false;

        return PostData(
          id: post['id'],
          userId: post['user_id'],
          username: user['username'],
          profileImageUrl: user['profile_image_url'],
          imageUrl: post['image_url'],
          caption: post['caption'],
          location: post['location'],
          createdAt: DateTime.parse(post['created_at']),
          likeCount: likes.length,
          commentCount: comments.length,
          isLiked: isLiked,
          isSaved: savedPostIds.contains(postId),
          disableComments: post['disable_comments'] ?? false,
          use_original_ratio: post['use_original_ratio'],
          image_transformation: post['image_transformation'],
          original_aspect_ratio: (post['original_aspect_ratio'] as num?)?.toDouble() ?? 1.0,
        );
      }).toList();

      // Filter out blocked users from followers and following lists
      final blockedService = BlockedUsersService();
      final blockedUsers = await blockedService.getBlockedUsers();
      final blockedIds = blockedUsers.map((u) => u['id']).toSet();

      final followersRes = await supabase.from('followers').select('follower_id').eq('following_id', userId);
      final followingRes = await supabase.from('followers').select('following_id').eq('follower_id', userId);

      final filteredFollowers = (followersRes as List)
          .where((f) => !blockedIds.contains(f['follower_id']))
          .toList();
      final filteredFollowing = (followingRes as List)
          .where((f) => !blockedIds.contains(f['following_id']))
          .toList();

      return {
        'users': profileRes,
        'posts': fetchedPosts,
        'followers': filteredFollowers,
        'following': filteredFollowing,
      };
    } catch (e) {
      print('Error fetching profile data: $e');
      // Return empty data structure to prevent crashes
      return {
        'users': {},
        'posts': <PostData>[],
        'followers': [],
        'following': [],
      };
    }
  }

  // Replace your _fetchTaggedPosts method with this complete version:
  Future<List<PostData>> _fetchTaggedPosts(String userId) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      // Session/user is not available, return empty list
      return [];
    }
    final currentUserId = currentUser.id;

    try {
      // First, let's fetch all posts and filter them in Dart to avoid JSON parsing issues
      final response = await supabase
          .from('posts')
          .select('''
        id,
        user_id,
        caption,
        location,
        image_url,
        created_at,
        disable_comments,
        use_original_ratio,
        image_transformation,
        original_aspect_ratio,
        users (
          username,
          profile_image_url
        ),
        tagged_users
      ''')
          .order('created_at', ascending: false);

      // Filter posts where the user is tagged
      final filteredPosts = (response as List).where((post) {
        final taggedUsers = post['tagged_users'];
        if (taggedUsers == null) return false;

        // Handle different possible formats of tagged_users
        try {
          if (taggedUsers is List) {
            // If it's already a List, check if any item has the userId
            return taggedUsers.any((user) {
              if (user is Map && user.containsKey('id')) {
                return user['id'].toString() == userId;
              }
              return false;
            });
          } else if (taggedUsers is String) {
            // If it's a string, it might be JSON that needs parsing
            // But we'll be careful about parsing
            return taggedUsers.contains(userId);
          }
        } catch (e) {
          print('Error parsing tagged_users for post ${post['id']}: $e');
          return false;
        }

        return false;
      }).toList();

      // Get all post IDs from the filtered posts
      final postIds = filteredPosts.map((post) => post['id']).toList();

      if (postIds.isEmpty) {
        return [];
      }

      // Fetch all likes for these posts
      final likesResponse = await supabase
          .from('post_likes')
          .select('post_id, user_id')
          .inFilter('post_id', postIds);

      // Fetch all comments for these posts
      final commentsResponse = await supabase
          .from('comments')
          .select('id, post_id')
          .inFilter('post_id', postIds);

      // Fetch saved posts for the current user
      List<dynamic> savedResponse = [];
      if (currentUserId != null) {
        savedResponse = await supabase
            .from('saved_posts')
            .select('post_id')
            .eq('user_id', currentUserId)
            .inFilter('post_id', postIds);
      }

      // Group likes, comments, and saves by post_id for easier lookup
      final Map<String, List<dynamic>> likesByPost = {};
      final Map<String, List<dynamic>> commentsByPost = {};
      final Set<String> savedPostIds = savedResponse.map((save) => save['post_id'].toString()).toSet();

      for (final like in likesResponse as List) {
        final postId = like['post_id'].toString();
        likesByPost[postId] = (likesByPost[postId] ?? [])..add(like);
      }

      for (final comment in commentsResponse as List) {
        final postId = comment['post_id'].toString();
        commentsByPost[postId] = (commentsByPost[postId] ?? [])..add(comment);
      }

      // Map filtered post data to PostData objects with correct counts
      return filteredPosts.map((post) {
        final user = post['users'];
        final postId = post['id'].toString();
        final likes = likesByPost[postId] ?? [];
        final comments = commentsByPost[postId] ?? [];

        final bool isLiked = currentUserId != null
            ? likes.any((like) => like['user_id'] == currentUserId)
            : false;

        return PostData(
          id: post['id'],
          userId: post['user_id'],
          username: user['username'],
          profileImageUrl: user['profile_image_url'],
          imageUrl: post['image_url'],
          caption: post['caption'],
          location: post['location'],
          createdAt: DateTime.parse(post['created_at']),
          likeCount: likes.length, // Now shows actual like count
          commentCount: comments.length, // Now shows actual comment count
          isLiked: isLiked, // Now shows actual like state
          isSaved: savedPostIds.contains(postId), // Now shows actual save state
          disableComments: post['disable_comments'] ?? false,
          use_original_ratio: post['use_original_ratio'],
          image_transformation: post['image_transformation'],
          original_aspect_ratio: (post['original_aspect_ratio'] as num?)?.toDouble() ?? 1.0,
        );
      }).toList();
    } catch (e) {
      print('Error fetching tagged posts: $e');
      return [];
    }
  }

  Future<void> _showImagePicker(String? userId) async {
    print('_showImagePicker called with userId: $userId');
    if (userId == null) {
      _showErrorSnackBar('Error: User not logged in');
      return;
    }

    final BuildContext context = this.context;

    try {
      List<Permission> permissionsToRequest = [
        Permission.camera,
        Permission.storage,
        Permission.photos,
      ];

      final statuses = await permissionsToRequest.request();
      final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final storageAccess =
          (statuses[Permission.storage]?.isGranted ?? false) ||
              (statuses[Permission.photos]?.isGranted ?? false);

      if (!cameraGranted || !storageAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Please grant required permissions to update picture'),
            ),
          );
        }
        return;
      }
    } catch (e) {
      _showErrorSnackBar('Please grant camera and storage access in settings');
      return;
    }

    try {
      final picker = ImagePicker();
      final loc = AppLocalizations.of(context)!;
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.grey[900],
        builder: (BuildContext ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(loc.updateProfilePicture,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.blue),
                  title: Text(loc.photoGallery),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: Text(loc.camera),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      );

      if (source != null && mounted) {
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 75,
          maxWidth: 800,
        );

        if (image != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );

          try {
            final bytes = await image.readAsBytes();
            final fileName =
                'public/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

            await Supabase.instance.client.storage.from('avatars').uploadBinary(
                fileName, bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'));

            Navigator.of(context).pop(); // close loading

            await Supabase.instance.client
                .from('users')
                .update({'profile_image_url': fileName}).eq('id', userId);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile image updated')),
            );

            setState(() {});
          } catch (e) {
            if (mounted) Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading image: $e')),
            );
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } else if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildAvatarSection(String? avatarUrl, Map<String, dynamic> profile) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return GestureDetector(
      onTap: () {
        if (userId != null) {
          _showImagePicker(userId);
        } else {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('Please log in to update your profile picture'),
            ),
          );
        }
      },
      child: Stack(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.grey[800],
            backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, color: Colors.white, size: 40)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.add_a_photo, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text("$count",
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  Widget _buildBioSection(Map profile) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 6, top: 20, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((profile['bio'] ?? '').isNotEmpty)
            Text(profile['bio'],
                style: const TextStyle(color: Colors.white70), maxLines: 3),
          if ((profile['website'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(profile['website'],
                  style: const TextStyle(color: Colors.blue, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );

                if (result == true) {
                  setState(() {}); // Refresh profile after editing
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(loc.editProfile,
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(loc.shareProfile,
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostTabs(List posts, String imageUrl) {
    final loc = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.grid_on)),
              Tab(icon: Icon(Icons.person_pin_outlined)),
            ],
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [
                posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 70,
                            ),
                            SizedBox(height: 16),
                            Text(
                              loc.noPostYet,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Photos and videos you share will appear here.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        itemCount: posts.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3),
                        itemBuilder: (context, index) {
                          final mediaPath = posts.cast<PostData>()[index].imageUrl;
                          final mediaUrl = mediaPath.toString().startsWith('http')
                              ? mediaPath
                              : Supabase.instance.client.storage
                                  .from('post-media')
                                  .getPublicUrl(mediaPath);
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SinglePostView(
                                      posts: posts.cast<PostData>(),
                                      initialIndex: index,
                                      Url: imageUrl),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                    image: CachedNetworkImageProvider(mediaUrl),
                                    fit: BoxFit.cover),
                              ),
                            ),
                          );
                        },
                      ),
                _buildTaggedGrid(Supabase.instance.client.auth.currentUser!.id),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTaggedGrid(String userId) {
    final loc = AppLocalizations.of(context)!;
    return FutureBuilder<List<PostData>>(
      future: _fetchTaggedPosts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error in tagged posts: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 70),
                SizedBox(height: 16),
                Text('Error loading tagged posts',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_pin_outlined, color: Colors.white, size: 70),
                SizedBox(height: 16),
                Text(loc.noPhotos,
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final taggedPosts = snapshot.data!;
        return GridView.builder(
          itemCount: taggedPosts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
          itemBuilder: (context, index) {
            final post = taggedPosts[index];
            final mediaUrl = post.imageUrl.toString().startsWith('http')
                ? post.imageUrl
                : Supabase.instance.client.storage.from('post-media').getPublicUrl(post.imageUrl);
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SinglePostView(
                      posts: taggedPosts,
                      initialIndex: index,
                      Url: post.profileImageUrl ?? '',
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(mediaUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showCreateSection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.black,
      isDismissible: true,
      builder: (context) {
        return GestureDetector(
          onTap: () {}, // Prevents tap-through dismiss
          child: DraggableScrollableSheet(
            initialChildSize: 0.95, // Adjust initial size to fit content better
            minChildSize: 0.2, // Can be smaller
            maxChildSize: 1.0, // Max size for the options
            expand: false,
            builder: (_, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      'Create',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24, thickness: 0.2),
                  _buildCreateOption(
                    iconWidget: Image.asset("assets/images/reelblack.png",color: Colors.white,width: 24,),
                    label: 'Reel',
                    onTap: () {
                      // Handle Reel tap
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CreatePostScreen(initialTabIndex: 2,))); // Close bottom sheet
                      print('Reel tapped!');
                    },
                  ),
                  _buildCreateOption(
                    iconWidget: Icon(Icons.grid_on,color: Colors.white,),
                    label: 'Post',
                    onTap: () {
                      // Handle Post tap
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CreatePostScreen(initialTabIndex: 0,)));
                      print('Post tapped!');
                    },
                  ),
                  _buildCreateOption(
                    iconWidget: Icon(Icons.add_circle_outline,color: Colors.white,),
                    label: 'Story',
                    onTap: () {
                      // Handle Story tap
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CreatePostScreen(initialTabIndex: 1,)));
                      print('Story tapped!');
                    },
                  ),
                  _buildCreateOption(
                    iconWidget: Icon(Icons.live_tv,color: Colors.white,),
                    label: 'Live',
                    onTap: () {
                      // Handle Live tap
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CreatePostScreen(initialTabIndex: 3,)));
                    },
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom), // Spacing for safe area
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCreateOption({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: iconWidget,
      title: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: onTap,
    );
  }
}
