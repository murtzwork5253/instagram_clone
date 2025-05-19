import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> searchResults = [];

  // Sample data - in real app, you might want to pass this from parent or fetch from a service
  final List<String> recentSearches = [
    'Flutter',
    'Drake',
    'Lo-Fi',
    'Coding',
    'Taylor'
  ];

  final List<String> allItems = [
    'Flutter',
    'React Native',
    'Drake',
    'Eminem',
    'Lo-Fi Beats',
    'Code Music',
    'Taylor Swift',
    'Kendrick',
    'Dark Mode',
    'AI Tools',
  ];

  @override
  void initState() {
    super.initState();
    // Start with an empty search
    _searchController.addListener(() {
      _selectChanged(_searchController.text);
    });
  }

  void _selectChanged(String query) {
    print("Searching for: '$query'");
    setState(() {
      searchResults = allItems
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
      print("Updated results: $searchResults (${searchResults.length} items)");
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            autofocus: true, // Auto-focus when screen opens
            controller: _searchController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 3, horizontal: 10),
              hintText: 'Search...',
              hintStyle: TextStyle(fontSize: 19),
              prefixIcon: Icon(Icons.search, color: Colors.grey),
            ),
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Searches
                if (_searchController.text.isEmpty) ...[
                  Text('Recent Searches',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: recentSearches.map((term) {
                      return GestureDetector(
                        onTap: () {
                          _searchController.text = term;
                          _selectChanged(term); // triggers search immediately
                        },
                        child: Chip(
                          label: Text(term),
                          backgroundColor: Colors.grey[800],
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Search Results - Only show if we have text in search
                if (_searchController.text.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Results',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      // Debug counter
                      Text("Found ${searchResults.length} items",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 8),

                  // The ListView.builder with a reliable key
                  ListView.builder(
                    key: ValueKey<String>(_searchController
                        .text), // This forces rebuild when search text changes
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(searchResults[index],
                            style: TextStyle(color: Colors.white)),
                        leading: Icon(Icons.search, color: Colors.white),
                        onTap: () {
                          // Handle tap - maybe navigate or add to recent searches
                          print("Selected: ${searchResults[index]}");
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
