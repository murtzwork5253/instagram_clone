// followers_following_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import your current user profile screen
import 'package:Instagram/screens/profilescreen/current_user_profile.dart'; // Adjust path if necessary
// Import your other user profile screen
import 'package:Instagram/screens/profilescreen/other_user_profile_screen.dart'; // Make sure this path is correct
import '../../services/blocked_users_service.dart';

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
  String? _currentUserId; // This stores the ID of the currently logged-in user

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.isFollowersTab ? 0 : 1,
    );
    _getCurrentUserId(); // Fetch current user's ID on init
  }

  void _getCurrentUserId() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    }
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(true), // Followers tab
          _buildUserList(false), // Following tab
        ],
      ),
    );
  }

  Widget _buildUserList(bool isFollowersTab) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: isFollowersTab
          ? _fetchFollowers(widget.userId)
          : _fetchFollowing(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text(
                  isFollowersTab ? 'No followers found.' : 'Not following anyone.',
                  style: const TextStyle(color: Colors.white)));
        }

        final users = snapshot.data!;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final String userId = user['id'];
            final String username = user['username'];
            final String? profileImageUrl = user['profile_image_url'];
            // Access 'is_following' with null-aware operator, it's added in fetch methods
            final bool isFollowing = user['is_following'] ?? false;

            return GestureDetector(
              onTap: () {
                if (_currentUserId != null && userId == _currentUserId) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            OtherUserProfileScreen(userId: userId)),
                  );
                }
              },
              onLongPress: () {
                // Only allow long-press to remove follower if on the followers tab
                // and the user being pressed is not the current user themselves.
                if (isFollowersTab && _currentUserId != null && userId != _currentUserId) {
                  _showRemoveFollowerDialog(context, userId, username);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl)
                          : null,
                      child: profileImageUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                      backgroundColor: Colors.grey[800],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Show follow/unfollow button only if it's not the current user's own profile
                    if (userId != _currentUserId && _currentUserId != null)
                      ElevatedButton(
                        onPressed: () => _toggleFollow(userId, isFollowing),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          isFollowing ? Colors.grey[800] : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: isFollowing
                                ? BorderSide(color: Colors.grey[700]!)
                                : BorderSide.none,
                          ),
                        ),
                        child: Text(isFollowing ? 'Following' : 'Follow'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRemoveFollowerDialog(
      BuildContext context, String followerId, String username) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Remove Follower?', style: TextStyle(color: Colors.white)),
          content: Text('Remove $username from your followers?',
              style: const TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _removeFollower(followerId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeFollower(String followerId) async {
    try {
      if (_currentUserId == null) {
        // Should not happen if _getCurrentUserId runs successfully
        print('Error: Current user ID is null. Cannot remove follower.');
        return;
      }

      print('$followerId, $_currentUserId');

      await supabase
          .from('followers')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', _currentUserId!);

      // Refresh the followers list after removal
      setState(() {
        _fetchFollowers(widget.userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Follower removed successfully!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      print('Error removing follower: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to remove follower.'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFollowers(String userId) async {
    final response = await supabase
        .from('followers')
        .select('follower_id')
        .eq('following_id', userId);

    final followerIds = (response as List)
        .map((e) => e['follower_id'] as String)
        .toList();

    if (followerIds.isEmpty) return [];

    final userData = await supabase
        .from('users')
        .select('id, username, profile_image_url')
        .inFilter('id', followerIds);

    // Filter out blocked users
    final blockedService = BlockedUsersService();
    final blockedUsers = await blockedService.getBlockedUsers();
    final blockedIds = blockedUsers.map((u) => u['id']).toSet();
    final filtered = userData.where((u) => !blockedIds.contains(u['id'])).toList();

    if (_currentUserId == null) {
      return filtered;
    }

    for (var user in filtered) {
      final followingCheck = await supabase
          .from('followers')
          .select()
          .eq('follower_id', _currentUserId!)
          .eq('following_id', user['id']);
      user['is_following'] = followingCheck.isNotEmpty;
    }

    return filtered;
  }

  Future<List<Map<String, dynamic>>> _fetchFollowing(String userId) async {
    final response = await supabase
        .from('followers')
        .select('following_id')
        .eq('follower_id', userId);

    final followingIds = (response as List)
        .map((e) => e['following_id'] as String)
        .toList();

    if (followingIds.isEmpty) return [];

    final userData = await supabase
        .from('users')
        .select('id, username, profile_image_url')
        .inFilter('id', followingIds);

    // Filter out blocked users
    final blockedService = BlockedUsersService();
    final blockedUsers = await blockedService.getBlockedUsers();
    final blockedIds = blockedUsers.map((u) => u['id']).toSet();
    final filtered = userData.where((u) => !blockedIds.contains(u['id'])).toList();

    if (_currentUserId == null) {
      return filtered;
    }

    if (_currentUserId == widget.userId) {
      for (var user in filtered) {
        user['is_following'] = true;
      }
    } else {
      for (var user in filtered) {
        final followingCheck = await supabase
            .from('followers')
            .select()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', user['id']);
        user['is_following'] = followingCheck.isNotEmpty;
      }
    }

    return filtered;
  }

  Future<void> _toggleFollow(String userId, bool isCurrentlyFollowing) async {
    if (_currentUserId == null) {
      print('Error: Current user ID is null. Cannot toggle follow status.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please log in to follow/unfollow.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    try {
      if (isCurrentlyFollowing) {
        await supabase
            .from('followers')
            .delete()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', userId);
      } else {
        await supabase.from('followers').insert({
          'follower_id': _currentUserId!,
          'following_id': userId,
        });
      }

      // Refresh the UI to reflect the change
      setState(() {
        // Re-fetch the current tab's list to update its content
        if (_tabController.index == 0) { // Following tab
          _fetchFollowing(widget.userId);
        } else { // Followers tab
          _fetchFollowers(widget.userId);
        }
      });
    } catch (e) {
      print('Error toggling follow status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update follow status: $e'),
            backgroundColor: Colors.red),
      );
    }
  }
}