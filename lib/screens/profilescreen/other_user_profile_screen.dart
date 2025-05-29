// other_user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Instagram/screens/profilescreen/followers_following_screen.dart'; // Import FollowersList

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
  List<dynamic> posts = [];
  bool isFollowing = false;
  bool isLoading = true;
  int followersCount = 0;
  int followingCount = 0;
  int postsCount = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOtherProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load profile details
      final profileRes = await supabase
          .from('users')
          .select()
          .eq('id', widget.userId)
          .single();

      // Load posts
      final postRes = await supabase
          .from('posts')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      // Check if current user is following this profile
      final followRes = await supabase.from('followers').select().match({
        'follower_id': supabase.auth.currentUser!.id,
        'following_id': widget.userId
      });

      // Count followers
      final followersRes = await supabase
          .from('followers')
          .select('count')
          .eq('following_id', widget.userId);
      final followersCountData = followersRes[0]['count'];

      // Count following
      final followingRes = await supabase
          .from('followers')
          .select('count')
          .eq('follower_id', widget.userId);
      final followingCountData = followingRes[0]['count'];

      setState(() {
        profile = profileRes;
        posts = postRes;
        postsCount = posts.length;
        isFollowing = followRes.isNotEmpty;
        followersCount = followersCountData;
        followingCount = followingCountData;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = supabase.auth.currentUser!.id;

    setState(() {
      // Optimistic UI update
      isFollowing = !isFollowing;
      // Note: followersCount update here is just for optimistic UI.
      // Real counts should ideally be updated via Supabase functions or a re-fetch.
      followersCount = isFollowing ? followersCount + 1 : followersCount - 1;
    });

    try {
      if (!isFollowing) {
        // If we just unfollowed (state already toggled above)
        await supabase.from('followers').delete().match(
            {'follower_id': currentUserId, 'following_id': widget.userId});
      } else {
        // If we just followed (state already toggled above)
        await supabase.from('followers').insert({
          'follower_id': currentUserId,
          'following_id': widget.userId,
        });
      }
      // Re-fetch counts after actual DB operation to ensure accuracy
      await _loadOtherProfile();
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        isFollowing = !isFollowing;
        followersCount = isFollowing ? followersCount + 1 : followersCount - 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating follow status: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _showBottomSheet(context);
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
                child: _buildProfileHeader(),
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
              _buildTaggedGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
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
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
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
                    _buildStatColumn(postsCount, 'Posts', null), // Posts are always visible
                    // Conditional display for Followers and Following lists
                    _buildStatColumn(
                      followersCount,
                      'Followers',
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
                      'Following',
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
                    isFollowing ? 'Following' : 'Follow',
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
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'Message',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // More options icon button
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: const EdgeInsets.all(0),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 36,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),

          // Similar accounts
          const SizedBox(height: 16),
          _buildSuggestedAccounts(),
        ],
      ),
    );
  }

  // Modified _buildStatColumn to accept an onTap callback
  Widget _buildStatColumn(int count, String label, VoidCallback? onTap) {
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
            const Text(
              'No Posts Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final mediaPath = posts[index]['image_url'];
        final mediaUrl = mediaPath.toString().startsWith('http')
            ? mediaPath
            : supabase.storage.from('post-media').getPublicUrl(mediaPath);

        return GestureDetector(
          onTap: () {
            // Navigate to post detail
          },
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(mediaUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaggedGrid() {
    // In a real app, you would fetch tagged posts
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_pin_outlined,
            color: Colors.white,
            size: 70,
          ),
          SizedBox(height: 16),
          Text(
            'No Photos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: Colors.white),
            title: const Text('Block', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.white),
            title: const Text('Report', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white),
            title: const Text('Share Profile',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add_disabled, color: Colors.white),
            title:
            const Text('Restrict', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
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