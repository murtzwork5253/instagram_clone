// other_user_profile_screen.dart
import 'package:Instagram/screens/chatscreen/chat_screen.dart';
import 'package:Instagram/screens/profilescreen/single_post_view.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Instagram/screens/profilescreen/followers_following_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../services/blocked_users_service.dart';
import 'report_user_dialog.dart';

import '../../services/supabase_service.dart'; // Import FollowersList
import 'package:cached_network_image/cached_network_image.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;

  const OtherUserProfileScreen({required this.userId, Key? key})
      : super(key: key);

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? profile;

  List<PostData> posts = [];

  bool isFollowing = false;
  bool isLoading = true;
  int followersCount = 0;
  int followingCount = 0;
  int postsCount = 0;
  late TabController _tabController;
  bool _showSuggestedAccounts = false;
  final BlockedUsersService _blockedUsersService = BlockedUsersService();
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOtherProfile(); // This will now only load profile info
    // _fetchInitialPosts(); // This will load the first page of posts
    _checkIfBlocked();
  }

  // Future<void> _fetchInitialPosts() async {
  //   await _fetchPosts(page: 0);
  // }
  //
  // // --- NEW: Paginated post fetching logic ---
  // Future<void> _fetchPosts({required int page}) async {
  //   if (!mounted) return;
  //   setState(() => _isLoadingPosts = true);
  //
  //   try {
  //     final newPosts = await SupabaseService.getPostsForUser(
  //       userId: widget.userId,
  //       page: page,
  //       pageSize: _postsPerPage,
  //     );
  //
  //     if (mounted) {
  //       setState(() {
  //         if (newPosts.length < _postsPerPage) {
  //           _hasMorePosts = false;
  //         }
  //         posts.addAll(newPosts);
  //         _currentPage = page;
  //         _isLoadingPosts = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() => _isLoadingPosts = false);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error loading posts: $e')),
  //       );
  //     }
  //   }
  // }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherProfile() async {
    setState(() => isLoading = true);
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // First, get the list of users blocked by the current user.
      final blockedUsers = await _blockedUsersService.getBlockedUsers();
      final blockedIds = blockedUsers.map((u) => u['id'].toString()).toList();

      // Now, run the parallel queries with the correct parameters.
      final List<Future<dynamic>> futures = [
        supabase.from('users').select().eq('id', widget.userId).single(),
        SupabaseService.getPostsForUser(userId: widget.userId, page: 0, pageSize: 100),
        // --- THIS IS THE FIX ---
        // Call the RPC with both parameters to resolve the ambiguity.
        supabase.rpc('get_follow_counts', params: {
          'user_id_input': widget.userId,
          'blocked_ids': blockedIds, // Pass the list of blocked user IDs
        }),
        supabase.rpc('is_user_following', params: {'follower_id_input': currentUserId, 'following_id_input': widget.userId}),
      ];

      final results = await Future.wait(futures);

      final profileRes = results[0] as Map<String, dynamic>;
      final postsRes = results[1] as List<PostData>;
      final countsRes = results[2] as Map<String, dynamic>;
      final isFollowingCheck = results[3] as bool;

      setState(() {
        profile = profileRes;
        posts = postsRes;
        followersCount = countsRes['followers'] ?? 0;
        followingCount = countsRes['following'] ?? 0;
        postsCount = posts.length;
        isFollowing = isFollowingCheck;
        isLoading = false;
      });

    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading other user profile: $e');
    }
  }

  Future<void> _checkIfBlocked() async {
    try {
      final isBlocked = await _blockedUsersService.isUserBlocked(widget.userId);
      setState(() => _isBlocked = isBlocked);
    } catch (e) {
      print('Error checking block status: $e');
    }
  }

  Future<void> _toggleBlock() async {
    try {
      if (_isBlocked) {
        await _blockedUsersService.unblockUser(widget.userId);
        setState(() => _isBlocked = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User unblocked')),
          );
        }
      } else {
        await _blockedUsersService.blockUser(widget.userId);
        setState(() => _isBlocked = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User blocked')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = supabase.auth.currentUser!.id;

    final originalFollowState = isFollowing;
    final originalFollowersCount = followersCount;

    setState(() {
      isFollowing = !isFollowing;
      followersCount += isFollowing ? 1 : -1;
    });

    try {
      if (!isFollowing) {
        await supabase.from('followers').delete().match(
            {'follower_id': currentUserId, 'following_id': widget.userId});
      } else {
        await supabase.from('followers').insert({
          'follower_id': currentUserId,
          'following_id': widget.userId,
        });
      }
      // Optional: A light re-fetch to ensure counts are perfectly in sync
      await _loadOtherProfile();
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        isFollowing = originalFollowState;
        followersCount = originalFollowersCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating follow status: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // First, handle the loading state.
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    // Second, handle the error/null state after loading is complete.
    if (profile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Error', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Text('Could not load user profile.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final rawAvatar = profile!['profile_image_url'];
    final avatarUrl = rawAvatar != null
        ? (rawAvatar.toString().startsWith('http')
        ? rawAvatar
        : supabase.storage.from('avatars').getPublicUrl(rawAvatar))
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          profile!['username'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              _showOptions();
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _buildProfileHeader(loc),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on)),
                      Tab(icon: Icon(Icons.person_pin_outlined)),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostsGrid(),
              _buildTaggedGrid(widget.userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(dynamic loc) {
    final loc = AppLocalizations.of(context)!;
    final rawAvatar = profile!['profile_image_url'];
    final avatarUrl = rawAvatar != null
        ? (rawAvatar.toString().startsWith('http')
        ? rawAvatar
        : supabase.storage.from('avatars').getPublicUrl(rawAvatar))
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Profile image
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[800],
                backgroundImage:
                avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                  profile!['username'] != null &&
                      profile!['username'].isNotEmpty
                      ? profile!['username'][0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 24),

              // Stats (posts, followers, following)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(postsCount, loc.posts, null), // Posts are always visible
                    // Conditional display for Followers and Following lists
                    _buildStatColumn(
                      followersCount,
                      loc.followers,
                      isFollowing // Only enable tap if following
                          ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FollowersList(
                              userId: widget.userId,
                              isFollowersTab: true,
                            ),
                          ),
                        );
                      }
                          : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Follow this user to see their followers.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    ),
                    _buildStatColumn(
                      followingCount,
                      loc.following,
                      isFollowing // Only enable tap if following
                          ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FollowersList(
                              userId: widget.userId,
                              isFollowersTab: false,
                            ),
                          ),
                        );
                      }
                          : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Follow this user to see who they follow.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Full name
          const SizedBox(height: 12),
          Text(
            profile!['full_name'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          // Bio
          if (profile!['bio'] != null && profile!['bio'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                profile!['bio'],
                style: const TextStyle(color: Colors.white),
              ),
            ),

          // Action buttons
          const SizedBox(height: 16),
          Row(
            children: [
              // Follow/Unfollow button
              Expanded(
                child: ElevatedButton(
                  onPressed: _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    isFollowing ? Colors.grey[800] : Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    isFollowing ? loc.following : loc.follow,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Message button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(currentUserId: supabase.auth.currentUser!.id, initialChatUserId: widget.userId,cameFromProfile: true,)));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    loc.message,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // More options icon button
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 41,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  padding: const EdgeInsets.all(0),
                  constraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 34,
                  ),
                  icon: Icon( _showSuggestedAccounts
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                      color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showSuggestedAccounts = !_showSuggestedAccounts;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _showSuggestedAccounts
                ? _buildSuggestedAccounts()
                : SizedBox.shrink(),
          )
        ],
      ),
    );
  }

  // Modified _buildStatColumn to accept an onTap callback
  Widget _buildStatColumn(int count, String label, VoidCallback? onTap) {
    final loc = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap, // Assign the onTap callback here
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedAccounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggested for you',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5, // Mock data
            itemBuilder: (context, index) {
              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[700],
                      child: Icon(Icons.person, color: Colors.grey[300]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'user_${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostsGrid() {
    final loc = AppLocalizations.of(context)!;
    // Check if user is following or if it's their own profile
    final currentUserId = supabase.auth.currentUser!.id;
    final isOwnProfile = widget.userId == currentUserId;

    // If it's not their own profile and they're not following, show private message
    if (!isOwnProfile && !isFollowing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              color: Colors.white,
              size: 70,
            ),
            const SizedBox(height: 16),
            Text(
              loc.accountPrivate,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.followToSeePosts,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Original posts grid logic for followed users or own profile
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 70,
            ),
            const SizedBox(height: 16),
            Text(
              loc.noPostYet,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final rawAvatar = profile!['profile_image_url'];
    final avatarUrl = rawAvatar != null
        ? (rawAvatar.toString().startsWith('http')
        ? rawAvatar
        : supabase.storage.from('avatars').getPublicUrl(rawAvatar))
        : null;

    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final mediaPath = posts.cast<PostData>()[index].imageUrl;
        final mediaUrl = mediaPath.toString().startsWith('http')
            ? mediaPath
            : supabase.storage.from('post-media').getPublicUrl(mediaPath);

        return GestureDetector(
          onTap: () {
            // Navigate to post detail
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SinglePostView(
                  posts: posts.cast<PostData>(),
                  initialIndex: index,
                  Url: avatarUrl,
                ),
              ),
            );
          },
          child: Container(
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

  Widget _buildTaggedGrid(String userId) {
    final loc = AppLocalizations.of(context)!;
    return FutureBuilder<List<PostData>>(
      future: _fetchTaggedPosts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_pin_outlined, color: Colors.white, size: 70),
                SizedBox(height: 16),
                Text(loc.noPhotos, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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

  void _showOptions() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              _isBlocked ? Icons.block_flipped : Icons.block,
              color: Colors.red,
            ),
            title: Text(
              _isBlocked ? 'Unblock' : 'Block',
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleBlock();
            },
          ),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.red),
            title: const Text('Report', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              final result = await showDialog(
                context: context,
                builder: (context) => ReportUserDialog(reportedUserId: widget.userId),
              );
              if (result == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. Thank you!')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white),
            title: Text(loc.shareProfile,
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          // ListTile(
          //   leading: const Icon(Icons.person_add_disabled, color: Colors.white),
          //   title: const Text('Restrict', style: TextStyle(color: Colors.white)),
          //   onTap: () {
          //     Navigator.pop(context);
          //   },
          // ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Custom delegate for tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.black,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}