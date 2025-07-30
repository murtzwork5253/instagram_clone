import 'package:Instagram/screens/calling/widgets/floating_call_indicator.dart';
import 'package:Instagram/screens/createscreens/create_post/create_post_screen.dart';
import 'package:Instagram/screens/profilescreen/current_user_profile.dart';
import 'package:Instagram/screens/searchscreen/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import '../calling/call_manager.dart';
import '../reels_screen/reels_screen.dart';
import 'account_switcher.dart';
import 'home_screen_feed.dart';

class HomeDashboard extends StatefulWidget {
  final int initialTabIndex;
  final String? initialReelId;

  const HomeDashboard({
    super.key,
    this.initialTabIndex = 0, // Default to home tab
    this.initialReelId,
  });

  @override
  State<HomeDashboard> createState() => _HomePageState();
}

class _HomePageState extends State<HomeDashboard> {
  int _currentIndex = 0;
  int _selectedBodyIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String? _avatarUrl;
  final ValueNotifier<int> homeRefreshNotifier = ValueNotifier(0);
  final ValueNotifier<int> profileRefreshNotifier = ValueNotifier(0);
  final ValueNotifier<int> searchRefreshNotifier = ValueNotifier(0);
  final ValueNotifier<int> reelsRefreshNotifier = ValueNotifier(0);

  void initState() {
    super.initState();
    // Use the initialTabIndex from the widget
    _currentIndex = widget.initialTabIndex;
    // Calculate the body index based on the initial tab index
    if (_currentIndex < 2) {
      _selectedBodyIndex = _currentIndex;
    } else {
      _selectedBodyIndex = _currentIndex - 1;
    }
    _loadCurrentUserAvatar();
    CallManager().initialize(context);
  }

  Future<void> _loadCurrentUserAvatar() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final response = await supabase
        .from('users')
        .select('profile_image_url')
        .eq('id', user.id)
        .single();

    if (response['profile_image_url'] != null) {
      setState(() {
        final rawUrl = response['profile_image_url'] as String;
        _avatarUrl = rawUrl.startsWith('http')
            ? rawUrl
            : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$rawUrl';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
    CallManager().dispose();
  }

  late final List<Widget> _pages = [
    InstagramHomeScreen(refreshNotifier: homeRefreshNotifier),
    InstagramSearchScreen(
      refreshNotifier: searchRefreshNotifier,
    ),
    Container(),
    ProfileScreen(refreshNotifier: profileRefreshNotifier),
  ];

  // Handle back navigation (modern approach with PopScope)
  void _handleBackNavigation() {
    if (_currentIndex != 0) {
      // If not on home page, navigate to home
      setState(() {
        _currentIndex = 0;
        _selectedBodyIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingCallIndicator(
      child: SafeArea(
        child: PopScope(
          canPop: _currentIndex == 0, // Only allow pop when on home screen
          onPopInvoked: (didPop) {
            if (!didPop) {
              _handleBackNavigation();
            }
          },
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
                    color: Colors.grey,
                  ),
                  activeIcon: Image.asset(
                    "assets/images/homefill.png",
                    width: 24,
                    height: 24,
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
                      "assets/icon/add_post_icon.png",
                      width: 22,
                      height: 22,
                      color: Colors.grey,
                    ),
                    activeIcon: Image.asset(
                      "assets/icon/add_post_icon.png",
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
                  icon: _buildProfileIcon(isActive: false),
                  activeIcon: _buildProfileIcon(isActive: true),
                ),
              ],
              onTap: (index) {
                if (_currentIndex == index) {
                  // Same tab tapped again - trigger refresh
                  _refreshCurrentTab(index);
                } else {
                  // Handle "Create Post" tab differently
                  if (index == 2) {
                    // Assuming Create Post is index 2
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const CreatePostScreen(
                          initialTabIndex: 0,
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin =
                              Offset(-1.0, 0.0); // Starts from the right
                          const end = Offset.zero; // Ends at its normal position
                          const curve = Curves.ease;

                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));

                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                        fullscreenDialog:
                            true, // Optional: still makes it feel like a modal
                      ),
                    );
                  } else {
                    // For other tabs (Home, Search, Reels, Profile)
                    setState(() {
                      _currentIndex =
                          index; // Update the visual selected item in BottomNavigationBar

                      // Calculate the _selectedBodyIndex for IndexedStack
                      if (index < 2) {
                        _selectedBodyIndex =
                            index; // For Home (0) and Search (1), it's the same index
                      } else {
                        // For Reels (index 3) and Profile (index 4), subtract 1
                        // because index 2 (Create Post) is skipped in our _pages list.
                        _selectedBodyIndex = index - 1;
                      }
                    });
                  }
                }
              },
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: false,
              type: BottomNavigationBarType.fixed,
            ),
            body: IndexedStack(
              index: _selectedBodyIndex,
              children: [
                _pages[0],
                // Home
                _pages[1],
                // Search
                _selectedBodyIndex == 2
                    ? ReelsScreen(
                        refreshNotifier: reelsRefreshNotifier,
                        initialReelId: widget.initialReelId, // Pass the ID here
                      )
                    : Container(),
                // Only create ReelsScreen when selected
                _pages[3],
                // Profile
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileIcon({required bool isActive}) {
    final double size = 26;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => const AccountSwitcherModal(),
        );
      },
      child: Container(
        padding: EdgeInsets.all(1), // border thickness
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isActive ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey[800],
          backgroundImage:
              _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
          child: _avatarUrl == null
              ? Icon(Icons.person, size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  void _refreshCurrentTab(int index) {
    switch (index) {
      case 0: // Home
        homeRefreshNotifier.value++;
        break;
      case 1:
        searchRefreshNotifier.value++;
        break;
      case 3:
        reelsRefreshNotifier.value++;
        break;
      case 4: // Profile (assuming profile tab is index 4)
        profileRefreshNotifier.value++;
        break;
      // Add more if needed
    }
  }
}
