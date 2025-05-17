import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showUserResults = false;

  final List<String> _recentSearches = [
    'flutterdev',
    'designs',
    'travel',
    'coding',
  ];

  final List<Map<String, String>> _users = [
    {
      'username': 'flutterdev',
      'name': 'Flutter Developer',
      'avatar': 'https://i.pravatar.cc/150?img=5',
    },
    {
      'username': 'john_doe',
      'name': 'John Doe',
      'avatar': 'https://i.pravatar.cc/150?img=12',
    },
    {
      'username': 'jane.art',
      'name': 'Jane Artist',
      'avatar': 'https://i.pravatar.cc/150?img=20',
    },
  ];

  final List<String> _dummyImages = List.generate(
    20,
    (index) => 'https://picsum.photos/seed/$index/200/200',
  );

  void _onSearchChanged(String value) {
    setState(() {
      _showUserResults = value.isNotEmpty;
    });
  }

  void _selectRecent(String search) {
    _searchController.text = search;
    _onSearchChanged(search);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Search',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      body: _showUserResults ? _buildUserResults() : _buildDefaultSearch(),
    );
  }

  Widget _buildDefaultSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recentSearches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Recent searches',
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ..._recentSearches.map((term) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(term),
              onTap: () => _selectRecent(term),
            )),
        const Divider(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            itemCount: _dummyImages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemBuilder: (context, index) {
              return Image.network(
                _dummyImages[index],
                fit: BoxFit.cover,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserResults() {
    final keyword = _searchController.text.toLowerCase();
    final filteredUsers = _users.where((user) {
      return user['username']!.toLowerCase().contains(keyword) ||
          user['name']!.toLowerCase().contains(keyword);
    }).toList();

    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user['avatar']!),
          ),
          title: Text(user['name']!),
          subtitle: Text('@${user['username']}'),
          onTap: () {
            // Navigate to profile screen later
          },
        );
      },
    );
  }
}
