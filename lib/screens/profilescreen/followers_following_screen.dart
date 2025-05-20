import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FollowersList extends StatefulWidget {
  final String userId;
  final bool isFollowersTab; // true for followers, false for following

  const FollowersList({
    Key? key,
    required this.userId,
    required this.isFollowersTab,
  }) : super(key: key);

  @override
  State<FollowersList> createState() => _FollowersListState();
}

class _FollowersListState extends State<FollowersList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.isFollowersTab ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(''),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowersList(),
          _buildFollowingList(),
        ],
      ),
    );
  }

  Widget _buildFollowersList() {
    return FutureBuilder<List<dynamic>>(
      future: _fetchFollowers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading followers',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final followers = snapshot.data ?? [];

        if (followers.isEmpty) {
          return const Center(
            child: Text(
              'No followers yet',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          itemCount: followers.length,
          itemBuilder: (context, index) {
            final userData = followers[index];
            return _buildUserListTile(userData);
          },
        );
      },
    );
  }

  Widget _buildFollowingList() {
    return FutureBuilder<List<dynamic>>(
      future: _fetchFollowing(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading following',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final following = snapshot.data ?? [];

        if (following.isEmpty) {
          return const Center(
            child: Text(
              'Not following anyone yet',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          itemCount: following.length,
          itemBuilder: (context, index) {
            final userData = following[index];
            return _buildUserListTile(userData);
          },
        );
      },
    );
  }

  Widget _buildUserListTile(Map<String, dynamic> userData) {
    // Handle profile image URL
    String? avatarUrl;
    if (userData['profile_image_url'] != null) {
      final imageUrl = userData['profile_image_url'];
      if (imageUrl.toString().startsWith('http')) {
        avatarUrl = imageUrl;
      } else {
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(imageUrl);
      }
    }

    final currentUserId = supabase.auth.currentUser!.id;
    final isCurrentUserFollowing = userData['is_following'] ?? false;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[800],
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
      title: Text(
        userData['username'] ?? 'User',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        userData['full_name'] ?? '',
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: userData['id'] != currentUserId
          ? ElevatedButton(
              onPressed: () =>
                  _toggleFollow(userData['id'], isCurrentUserFollowing),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isCurrentUserFollowing ? Colors.grey[800] : Colors.blue,
                minimumSize: const Size(88, 32),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                isCurrentUserFollowing ? 'Following' : 'Follow',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
      onTap: () {
        // Navigate to user profile
        // Navigator.push...
      },
    );
  }

  Future<List<dynamic>> _fetchFollowers() async {
    // Get users who follow the current user
    final followersData = await supabase
        .from('followers')
        .select('follower_id')
        .eq('following_id', widget.userId);

    if (followersData.isEmpty) return [];

    // Extract follower IDs
    final followerIds =
        followersData.map((item) => item['follower_id']).toList();

    // Fetch user details for all followers
    final userData = await supabase
        .from('users')
        .select('id, username, full_name, profile_image_url')
        .inFilter('id', followerIds);

    // Check if current user is following each of these users
    final currentUserId = supabase.auth.currentUser!.id;
    if (currentUserId == widget.userId) {
      // Current user is viewing their own followers
      for (var user in userData) {
        final followingCheck = await supabase
            .from('followers')
            .select()
            .eq('follower_id', currentUserId)
            .eq('following_id', user['id']);

        user['is_following'] = followingCheck.isNotEmpty;
      }
    }

    return userData;
  }

  Future<List<dynamic>> _fetchFollowing() async {
    // Get users that the current user follows
    final followingData = await supabase
        .from('followers')
        .select('following_id')
        .eq('follower_id', widget.userId);

    if (followingData.isEmpty) return [];

    // Extract following IDs
    final followingIds =
        followingData.map((item) => item['following_id']).toList();

    // Fetch user details for all following
    final userData = await supabase
        .from('users')
        .select('id, username, full_name, profile_image_url')
        .inFilter('id', followingIds);

    // If the current user is viewing their own following list, mark all as following
    final currentUserId = supabase.auth.currentUser!.id;
    if (currentUserId == widget.userId) {
      for (var user in userData) {
        user['is_following'] = true;
      }
    } else {
      // Check which users the current user is following
      for (var user in userData) {
        final followingCheck = await supabase
            .from('followers')
            .select()
            .eq('follower_id', currentUserId)
            .eq('following_id', user['id']);

        user['is_following'] = followingCheck.isNotEmpty;
      }
    }

    return userData;
  }

  Future<void> _toggleFollow(String userId, bool isCurrentlyFollowing) async {
    final currentUserId = supabase.auth.currentUser!.id;

    try {
      if (isCurrentlyFollowing) {
        // Unfollow
        await supabase
            .from('followers')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', userId);
      } else {
        // Follow
        await supabase.from('followers').insert({
          'follower_id': currentUserId,
          'following_id': userId,
        });
      }

      // Refresh the UI
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
