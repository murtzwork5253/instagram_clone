// lib/tag_users_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TagUsersScreen extends StatefulWidget {
  const TagUsersScreen({Key? key}) : super(key: key);

  @override
  State<TagUsersScreen> createState() => _TagUsersScreenState();
}

class _TagUsersScreenState extends State<TagUsersScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  List<String> _selectedUserIds = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await _supabase
          .from('users')
          .select('id, username, profile_image_url')
          .order('username', ascending: true); // Order users by username

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching users: $e';
      });
      print('Error fetching users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isUserSelected(String userId) {
    return _selectedUserIds.contains(userId);
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag People'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // In a real app, you would pass _selectedUserIds back
              // to the previous screen (ReelCaptionScreen) using Navigator.pop
              // For now, we'll just show a snackbar.
              print('Selected Users: $_selectedUserIds');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected ${_selectedUserIds.length} users!'),
                  duration: const Duration(seconds: 2),
                ),
              );
              Navigator.pop(context, _selectedUserIds); // Pass selected IDs back
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final userId = user['id'] as String;
          final username = user['username'] as String? ?? 'Unknown User';
          final profileImageUrl = user['profile_image_url'] as String?;

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : null,
              child: profileImageUrl == null || profileImageUrl.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(username),
            trailing: Checkbox(
              value: _isUserSelected(userId),
              onChanged: (bool? newValue) {
                _toggleUserSelection(userId);
              },
            ),
            onTap: () {
              _toggleUserSelection(userId);
            },
          );
        },
      ),
    );
  }
}