import 'package:Instagram/screens/profilescreen/other_user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => searchResults.clear());
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      // Add some debug prints
      print("Searching for: $query");

      final fullNameMatches = await supabase
          .from('users')
          .select('id, full_name, username, profile_image_url')
          .ilike('full_name', '%$query%');

      print("Full name matches: ${fullNameMatches.length}");

      final usernameMatches = await supabase
          .from('users')
          .select('id, full_name, username, profile_image_url')
          .ilike('username', '%$query%');

      print("Username matches: ${usernameMatches.length}");

      // Merge results and remove duplicates
      final Set<String> seen = {};
      final profiles = [...fullNameMatches, ...usernameMatches]
          .where((user) => seen.add(user['id'].toString()))
          .map((p) => {'type': 'users', 'data': p})
          .toList();

      print("Combined profiles: ${profiles.length}");

      final keywordResponse = await supabase
          .from('keywords')
          .select('id, term')
          .ilike('term', '%$query%');

      print("Keywords found: ${keywordResponse.length}");

      // Don't cast the response, just map it directly
      final keywords =
          keywordResponse.map((k) => {'type': 'keyword', 'data': k}).toList();

      setState(() {
        searchResults = [...profiles, ...keywords];
        print("Total search results: ${searchResults.length}");
      });
    } catch (e) {
      print("Search error: $e");
      // Show error in UI
      setState(() {
        searchResults = [
          {
            'type': 'error',
            'data': {'message': e.toString()}
          }
        ];
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Helper method to get profile image URL
  String? getProfileImageUrl(String? profileImageUrl) {
    if (profileImageUrl == null || profileImageUrl.isEmpty) {
      return null;
    }

    final supabase = Supabase.instance.client;

    // Check if the URL is already a complete URL
    if (profileImageUrl.startsWith('http')) {
      return profileImageUrl;
    }

    // If it's just a filename or path, construct the full URL
    // Assuming the bucket name is 'avatars'
    return supabase.storage.from('avatars').getPublicUrl(profileImageUrl);
  }

  // Widget to display profile image with fallback
  Widget buildProfileImage(String? imageUrl, String fallbackText) {
    final url = getProfileImageUrl(imageUrl);

    return CircleAvatar(
      backgroundColor: Colors.blueAccent,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(
              fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.white),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchController.text.isNotEmpty;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: TextFormField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search keywords or profiles...',
              hintStyle: TextStyle(fontSize: 18, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[850],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              suffixIcon: isSearching
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => searchResults.clear());
                      },
                    )
                  : null,
            ),
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(10),
          child: isSearching
              ? ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final result = searchResults[index];
                    final type = result['type'];
                    final data = result['data'];

                    if (type == 'users') {
                      final fullName = data['full_name'] ?? 'No Name';
                      final username = data['username'] ?? 'unknown';
                      final profileImageUrl = data['profile_image_url'];

                      return ListTile(
                        leading: buildProfileImage(profileImageUrl, fullName),
                        title: Text(fullName,
                            style: TextStyle(color: Colors.white)),
                        subtitle: Text('@$username',
                            style: TextStyle(color: Colors.grey)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OtherUserProfileScreen(userId: data['id']),
                            ),
                          );
                        },
                      );
                    } else if (type == 'keyword') {
                      return ListTile(
                        leading: Icon(Icons.tag, color: Colors.greenAccent),
                        title: Text(data['term'] ?? 'Unknown',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          print("Tapped on keyword: ${data['term']}");
                        },
                      );
                    } else if (type == 'error') {
                      return ListTile(
                        leading: Icon(Icons.error, color: Colors.red),
                        title: Text('Error searching',
                            style: TextStyle(color: Colors.red)),
                        subtitle: Text(data['message'],
                            style: TextStyle(color: Colors.grey)),
                      );
                    }

                    return SizedBox.shrink();
                  })
              : Center(
                  child: Text("Start typing to search...",
                      style: TextStyle(color: Colors.white70)),
                ),
        ),
      ),
    );
  }
}
