import 'package:Instagram/screens/createscreens/create_post_screen.dart';
import 'package:Instagram/screens/profilescreen/current_user_profile.dart';
import 'package:Instagram/screens/searchscreen/search_screen.dart';
import 'package:flutter/material.dart';

import 'home_screen_feed.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomePageState();
}

class _HomePageState extends State<HomeDashboard> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  // In initState, initialize searchResults with all items
  void initState() {
    super.initState();
  }

  List<String> recentSearches = [
    'Flutter',
    'Drake',
    'Lo-Fi',
    'Coding',
    'Taylor'
  ];
  List<String> allItems = [
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
  List<String> searchResults = [];

  void _selectChanged(String query) {
    print("Searching for: $query");
    setState(() {
      searchResults = allItems
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(() {
      _selectChanged(_searchController.text);
    });
    _searchController.dispose();
    super.dispose();
  }

  late final List<Widget> _pages = [
    InstagramHomeScreen(),
    InstagramSearchScreen(),
    CreatePostScreen(),
    _buildReelScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.black,
          showSelectedLabels: false,
          items: [
            BottomNavigationBarItem(
              label: "Home",
              icon: Image.asset(
                "assets/images/home.png",
                width: 23,
                height: 23,
                // For unselected state
                color: Colors.grey,
              ),
              activeIcon: Image.asset(
                "assets/images/homefill.png",
                width: 24,
                height: 24,
                // For selected state
                color: Colors.white,
              ),
            ),
            BottomNavigationBarItem(
              label: "Search",
              icon: Image.asset(
                "assets/images/glass.png",
                width: 23,
                height: 23,
                color: Colors.grey,
              ),
              activeIcon: Image.asset(
                "assets/images/glass.png",
                width: 23,
                height: 23,
                color: Colors.white,
              ),
            ),
            BottomNavigationBarItem(
                label: "Create Post",
                icon: Image.asset(
                  "assets/images/add-square-button.png",
                  width: 22,
                  height: 22,
                  color: Colors.grey,
                ),
                activeIcon: Image.asset(
                  "assets/images/add-square-button.png",
                  width: 22,
                  height: 22,
                  color: Colors.white,
                )),
            BottomNavigationBarItem(
              label: "Reels",
              icon: Image.asset(
                "assets/images/reelblack.png",
                width: 28,
                height: 28,
                color: Colors.grey,
              ),
              activeIcon: Image.asset(
                "assets/images/reel.png",
                width: 28,
                height: 28,
                color: Colors.white,
              ),
            ),
            BottomNavigationBarItem(
              label: "Profile",
              icon: Image.asset(
                "assets/images/user.png",
                width: 28,
                height: 28,
                color: Colors.grey,
              ),
              activeIcon: Image.asset(
                "assets/images/user.png",
                width: 28,
                height: 28,
                color: Colors.white,
              ),
            )
          ],
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
    );
  }

  Widget _buildReelScreen() {
    return SafeArea(
        child: Scaffold(
            appBar: AppBar(
      title: Text(
        "Reels",
        style: TextStyle(color: Colors.white),
      ),
    )));
  }
}
