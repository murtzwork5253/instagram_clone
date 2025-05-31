import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/chatscreen/model/models.dart' as models;
import '/screens/chatscreen/message_service.dart';

// --- New Chat Dialog Widget ---
class NewChatDialog extends StatefulWidget {
  final String currentUserId;
  final MessageService messageService;
  final Function(String userId, String username, String? profileUrl) onUserSelected;

  const NewChatDialog({
    Key? key,
    required this.currentUserId,
    required this.messageService,
    required this.onUserSelected,
  }) : super(key: key);

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<models.User> _searchResults = [];
  List<models.User> _allUsers = [];
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isLoadingAllUsers = true; // New state for loading all users

  @override
  void initState() {
    super.initState();
    _fetchAllUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // NEW CODE - Replace the above section with this:
  void _fetchAllUsers() async {
    setState(() {
      _isLoadingAllUsers = true;
    });
    try {
      final allUsers = await widget.messageService.searchUsers('', widget.currentUserId);
      print('All Users: $allUsers');

      setState(() {
        _allUsers = allUsers;
        _isLoadingAllUsers = false;
      });
      // print('All Users: $_allUsers');
      // print('All users fetched successfully');
    } catch (e) {
      print('Error fetching all users: $e');
      setState(() {
        _isLoadingAllUsers = false;
      });
    }
  }

  // NEW CODE - Replace the above section with this:
  void _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        // When search is cleared, we naturally fall back to displaying _allUsers
        // so no need to explicitly call _fetchAllUsers() here.
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final results = await widget.messageService.searchUsers(query, widget.currentUserId);

      // Only update if this is still the current search query
      if (_searchQuery == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (_searchQuery == query) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      print('Error searching users: $e');
    }
  }

  String _getProfileImageUrl(String? profileUrl) {
    if (profileUrl == null || profileUrl.isEmpty) {
      return 'https://via.placeholder.com/150'; // Default placeholder
    }
    if (profileUrl.startsWith('http://') || profileUrl.startsWith('https://')) {
      return profileUrl;
    }
    return 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$profileUrl';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.trim().isEmpty) {
      if (_isLoadingAllUsers) {
        return const Center(child: CircularProgressIndicator());
      } else if (_allUsers.isEmpty) {
        return const Center(
          child: Text(
            'No users available',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        );
      } else {
        return ListView.builder(
          itemCount: _allUsers.length,
          itemBuilder: (context, index) {
            final user = _allUsers[index];
            return ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(_getProfileImageUrl(user.profileImageUrl)),
                backgroundColor: Colors.grey[700],
                onBackgroundImageError: (exception, stackTrace) {
                  print('Error loading profile image: $exception');
                },
              ),
              title: Text(
                user.username,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              subtitle: user.email != null
                  ? Text(
                user.email!,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              )
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                widget.onUserSelected(user.id, user.username, user.profileImageUrl);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          },
        );
      }
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(_getProfileImageUrl(user.profileImageUrl)),
            backgroundColor: Colors.grey[700],
            onBackgroundImageError: (exception, stackTrace) {
              print('Error loading profile image: $exception');
            },
          ),
          title: Text(
            user.username,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          subtitle: user.email != null
              ? Text(
            user.email!,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          )
              : null,
          onTap: () {
            Navigator.of(context).pop();
            widget.onUserSelected(user.id, user.username, user.profileImageUrl);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      },
    );
  }
}