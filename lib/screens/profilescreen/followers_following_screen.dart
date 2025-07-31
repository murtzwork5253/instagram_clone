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
      // Use a key to ensure the FutureBuilder refetches when the tab changes
      key: ValueKey('${widget.userId}_$isFollowersTab'),
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
          // The RPC functions return an empty list if not authorized, so this message will show correctly.
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
            // *** FIX: The RPC function returns 'user_id', not 'id' ***
            final String userId = user['user_id'];
            final String username = user['username'];
            final String? profileImageUrl = user['profile_image_url'];
            final bool isFollowing = user['is_following'] ?? false;

            // Fixed profile image URL handling
            final String? publicUrl = profileImageUrl != null
                ? (profileImageUrl.startsWith('http')
                ? profileImageUrl
                : Supabase.instance.client.storage.from('avatars').getPublicUrl(profileImageUrl))
                : null;

            return GestureDetector(
              onTap: () {
                if (_currentUserId != null && userId == _currentUserId) {
                  // Navigate to the current user's own profile screen
                  // This pop might need adjustment based on your navigation stack
                  Navigator.of(context).popUntil((route) => route.isFirst);
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
                      backgroundImage: publicUrl != null
                          ? NetworkImage(publicUrl)
                          : null,
                      child: publicUrl == null
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
      if (_currentUserId == null) return;
      await supabase
          .from('followers')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', _currentUserId!);
      setState(() {}); // Refresh the list
    } catch (e) {
      print('Error removing follower: $e');
    }
  }

  // *** NEW IMPLEMENTATION USING RPC ***
  Future<List<Map<String, dynamic>>> _fetchFollowers(String userId) async {
    final response = await supabase.rpc(
      'get_followers_list',
      params: {'profile_id': userId},
    );

    if (response == null) return [];

    final List<Map<String, dynamic>> users = (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final blockedService = BlockedUsersService();
    final blockedUsers = await blockedService.getBlockedUsers();
    final blockedIds = blockedUsers.map((u) => u['id']).toSet();
    final filtered = users.where((u) => !blockedIds.contains(u['user_id'])).toList();

    if (_currentUserId == null) return filtered;

    for (var user in filtered) {
      final followingCheck = await supabase
          .from('followers')
          .select()
          .eq('follower_id', _currentUserId!)
          .eq('following_id', user['user_id']);
      user['is_following'] = followingCheck.isNotEmpty;
    }

    return filtered;
  }

  // *** NEW IMPLEMENTATION USING RPC ***
  Future<List<Map<String, dynamic>>> _fetchFollowing(String userId) async {
    final response = await supabase.rpc(
      'get_following_list',
      params: {'profile_id': userId},
    );

    if (response == null) return [];

    final List<Map<String, dynamic>> users = (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final blockedService = BlockedUsersService();
    final blockedUsers = await blockedService.getBlockedUsers();
    final blockedIds = blockedUsers.map((u) => u['id']).toSet();
    final filtered = users.where((u) => !blockedIds.contains(u['user_id'])).toList();

    if (_currentUserId == null) return filtered;

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
            .eq('following_id', user['user_id']);
        user['is_following'] = followingCheck.isNotEmpty;
      }
    }

    return filtered;
  }

  Future<void> _toggleFollow(String userId, bool isCurrentlyFollowing) async {
    if (_currentUserId == null) return;

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
      setState(() {}); // This is enough to trigger a rebuild of the FutureBuilder
    } catch (e) {
      print('Error toggling follow status: $e');
    }
  }
}
