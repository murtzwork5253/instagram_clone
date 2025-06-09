import 'package:flutter/material.dart';
import '../../services/blocked_users_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final BlockedUsersService _blockedUsersService = BlockedUsersService();
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final users = await _blockedUsersService.getBlockedUsers();
      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading blocked users: $e')),
        );
      }
    }
  }

  Future<void> _unblockUser(String userId, String username) async {
    try {
      await _blockedUsersService.unblockUser(userId);
      setState(() {
        _blockedUsers.removeWhere((user) => user['id'] == userId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unblocked $username')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unblocking user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Blocked Users', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _blockedUsers.isEmpty
              ? const Center(
                  child: Text(
                    'No blocked users',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user['profileImageUrl'] != null
                            ? NetworkImage(user['profileImageUrl'])
                            : null,
                        child: user['profileImageUrl'] == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        user['username'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: TextButton(
                        onPressed: () => _unblockUser(
                          user['id'],
                          user['username'],
                        ),
                        child: const Text(
                          'Unblock',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 