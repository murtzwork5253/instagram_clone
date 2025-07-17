// screens/user_tagging_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_model.dart';
import 'user_tagging_service.dart';

class UserTaggingScreen extends StatefulWidget {
  final String currentUserId;
  final List<TaggedUser> initialTaggedUsers;
  final String title;
  final Function(List<TaggedUser>) onUsersSelected;

  const UserTaggingScreen({
    Key? key,
    required this.currentUserId,
    this.initialTaggedUsers = const [],
    this.title = 'Tag People',
    required this.onUsersSelected,
  }) : super(key: key);

  @override
  State<UserTaggingScreen> createState() => _UserTaggingScreenState();
}

class _UserTaggingScreenState extends State<UserTaggingScreen> {
  final UserTaggingService _taggingService = UserTaggingService();
  final TextEditingController _searchController = TextEditingController();

  List<SearchableUser> _searchResults = [];
  List<TaggedUser> _selectedUsers = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedUsers = List.from(widget.initialTaggedUsers);
    _loadInitialUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialUsers() async {
    setState(() => _isSearching = true);

    final users = await _taggingService.searchUsers(
      query: '',
      currentUserId: widget.currentUserId,
    );

    setState(() {
      _searchResults = users;
      _isSearching = false;
    });
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    final users = await _taggingService.searchUsers(
      query: query,
      currentUserId: widget.currentUserId,
    );

    setState(() {
      _searchResults = users;
      _isSearching = false;
    });
  }

  void _toggleUserSelection(SearchableUser user) {
    setState(() {
      final existingIndex = _selectedUsers.indexWhere((u) => u.id == user.id);

      if (existingIndex != -1) {
        _selectedUsers.removeAt(existingIndex);
      } else {
        _selectedUsers.add(user.toTaggedUser());
      }
    });

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  bool _isUserSelected(String userId) {
    return _selectedUsers.any((user) => user.id == userId);
  }

  void _handleDone() {
    widget.onUsersSelected(_selectedUsers);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleDone,
            child: Text(
              'Done',
              style: TextStyle(
                color: Colors.blue[400],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            margin: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search people...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                if (value.trim() != _searchQuery) {
                  _searchUsers(value.trim());
                }
              },
            ),
          ),

          // Selected users preview
          if (_selectedUsers.isNotEmpty)
            Container(
              height: 100,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tagged (${_selectedUsers.length})',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 70,
                    child: SizedBox(
                      height: 90, // Move height constraint here
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _selectedUsers[index];
                          return _buildSelectedUserChip(user);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 18),

          // Search results
          Expanded(
            child: _isSearching
                ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
                : _searchResults.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No recent users found'
                        : 'No users found for "$_searchQuery"',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return _buildUserListItem(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedUserChip(TaggedUser user) {
    final String displayUrl = _getDisplayUrl(user.profileImageUrl);

    return Container(
      width: 70, // Fixed width for consistent spacing
      height: 80,
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: displayUrl.isNotEmpty
                    ? NetworkImage(displayUrl)
                    : null,
                backgroundColor: Colors.grey[800],
                child: displayUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
              Positioned(
                top: -1,
                right: -1,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedUsers.removeWhere((u) => u.id == user.id);
                    });
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              user.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Changed from clip to ellipsis for better UX
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListItem(SearchableUser user) {
    final bool isSelected = _isUserSelected(user.id);
    final String displayUrl = _getDisplayUrl(user.profileImageUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleUserSelection(user),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: displayUrl.isNotEmpty
                    ? NetworkImage(displayUrl)
                    : null,
                backgroundColor: Colors.grey[800],
                child: displayUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (user.fullName != null)
                      Text(
                        user.fullName!,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey[600]!,
                    width: 2,
                  ),
                  color: isSelected ? Colors.blue : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayUrl(String? profileUrl) {
    if (profileUrl == null || profileUrl.isEmpty) return '';

    if (profileUrl.startsWith('http://') || profileUrl.startsWith('https://')) {
      return profileUrl;
    }

    return 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$profileUrl';
  }
}