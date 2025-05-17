import 'package:Instagram/screens/homescreen/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:Instagram/screens/auth/login_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
import '../auth/auth_service.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomePageState();
}

class _HomePageState extends State<HomeDashboard> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  void initState() {
    super.initState();
    _searchController.addListener(() {
      _selectChanged(_searchController.text);
    });
  }

  late final List<Function()> _pages = [
    _buildHomeScreen,
    _buildSearchScreen,
    _buildCreateScreen,
    _buildReelScreen,
    _buildProfileScreen,
  ];

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
    setState(() {
      searchResults = allItems
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '1051202779186-kqac9ms2803rllegshdu2d3n6bjff23h.apps.googleusercontent.com', // Add this for better security
  );

  // Enhanced logout function
  Future<void> _logout() async {
    try {
      // setState(() => _isLoading = true);

      // 1. Sign out from Google
      await _googleSignIn.signOut();

      // 2. Sign out from Supabase
      await AuthService.client().auth.signOut();

      // 3. Clear any cached credentials
      // await _googleSignIn.disconnect();

      // Optional: Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {}
    }
  }

  // Static data for stories
  final List<Map<String, dynamic>> _stories = [
    {'username': 'Your Story', 'isMe': true, 'hasStory': false},
    {
      'username': 'adidas',
      'image': 'https://picsum.photos/200',
      'isViewed': false,
      'isMe': false,
      'hasStory': false
    },
    {
      'username': 'nike',
      'image': 'https://picsum.photos/201',
      'isViewed': true,
      'isMe': false,
      'hasStory': false
    },
    {
      'username': 'puma',
      'image': 'https://picsum.photos/202',
      'isViewed': false,
      'isMe': false,
      'hasStory': false
    },
    {
      'username': 'reebok',
      'image': 'https://picsum.photos/203',
      'isViewed': true,
      'isMe': false,
      'hasStory': false
    },
    {
      'username': 'sketchers',
      'image': 'https://picsum.photos/203',
      'isViewed': true,
      'isMe': false,
      'hasStory': false
    },
    {
      'username': 'reebok',
      'image': 'https://picsum.photos/203',
      'isViewed': false,
      'isMe': false,
      'hasStory': false
    },
  ];

  // Static data for posts
  final List<Map<String, dynamic>> _posts = [
    {
      'username': 'adidas',
      'location': 'Herzogenaurach, Germany',
      'image': 'https://picsum.photos/300',
      'likes': '12,345',
      'caption': 'Impossible is Nothing 💫\n#adidas #sport',
      'profileImage': 'https://picsum.photos/200',
      'time': '2 hours ago'
    },
    {
      'username': 'nike',
      'location': 'Beaverton, Oregon',
      'image': 'https://picsum.photos/301',
      'likes': '23,456',
      'caption': 'Just Do It. 🏃‍♂️💨\n#nike #athlete',
      'profileImage': 'https://picsum.photos/201',
      'time': '5 hours ago'
    },
    {
      'username': 'nike',
      'location': 'Beaverton, Oregon',
      'image': 'https://picsum.photos/301',
      'likes': '12,456',
      'caption': 'Just Do It. 🏃‍♂️💨\n#nike #athlete',
      'profileImage': 'https://picsum.photos/201',
      'time': '9 hours ago'
    },
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
        body: _pages[_currentIndex](),
      ),
    );
  }

  Widget _buildHomeScreen() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: false,
          floating: true,
          backgroundColor: Colors.black,
          title: Text(
            'Instagram',
            style: TextStyle(
              fontFamily: 'GrandHotel',
              fontSize: 33,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  _logout();
                },
                icon: Icon(
                  Icons.logout,
                  color: Colors.white,
                )),
            IconButton(
                onPressed: () {},
                icon: Image.asset(
                  "assets/images/image-removebg-preview.png",
                  width: 25,
                  height: 25,
                  color: Colors.white,
                ))
          ],
        ),
        SliverToBoxAdapter(
          child: _buildStories(),
        ),
        // SliverList(
        //     delegate: SliverChildBuilderDelegate(
        //   (context, index) => _buildPost(_posts[index]),
        // )),
        SliverToBoxAdapter(
          child: SizedBox(height: 10),
        ),
      ],
    );
  }

  Widget _buildStories() {
    // Sort stories - unviewed first, then viewed
    final sortedStories = List.from(_stories)
      ..sort((a, b) {
        if (a['isMe'] == true) return -1; // Your Story always first
        if (b['isMe'] == true) return 1;
        if (a['isViewed'] == false && b['isViewed'] == true) return -1;
        if (a['isViewed'] == true && b['isViewed'] == false) return 1;
        return 0;
      });

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sortedStories.length,
        itemBuilder: (context, index) => _buildStoryItem(sortedStories[index]),
      ),
    );
  }

  Widget _buildStoryItem(Map<String, dynamic> story) {
    return Container(
      width: 80,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: story['isViewed'] == true || story['isMe'] == true
                    ? LinearGradient(colors: [Colors.grey, Colors.grey])
                    : LinearGradient(
                        colors: [Colors.purple, Colors.orange, Colors.red]),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 38,
                backgroundColor: Colors.black,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.grey[800],
                  // Darker grey for better contrast
                  child: story['isMe'] == true
                      ? Icon(Icons.add,
                          size: 32,
                          color: Colors.white) // Standard "add story" icon
                      : ClipOval(
                          child: Image.network(
                            story['image'],
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.person, size: 40),
                          ),
                        ),
                ),
              )),
          SizedBox(height: 4),
          Text(
            "${story['username']}",
            style: TextStyle(),
          ),
        ],
      ),
    );
  }

  // Widget _buildPost(Map<String, dynamic> post) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       ListTile(
  //         leading: CircleAvatar(
  //           backgroundImage: NetworkImage(post['profileImage']),
  //         ),
  //         title: Text(post['username'],
  //             style:
  //                 TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  //         subtitle:
  //             Text(post['location'], style: TextStyle(color: Colors.white)),
  //         trailing: Icon(Icons.more_vert, color: Colors.white),
  //       ),
  //       Image.network(post['image'],
  //           width: double.infinity,
  //           height: MediaQuery.of(context).size.width,
  //           fit: BoxFit.cover),
  //       Padding(
  //         padding: EdgeInsets.all(12),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               children: [
  //                 Icon(Icons.favorite_border, color: Colors.white),
  //                 SizedBox(width: 12),
  //                 Icon(Icons.mode_comment_outlined, color: Colors.white),
  //                 SizedBox(width: 12),
  //                 Icon(Icons.send_outlined, color: Colors.white),
  //                 Spacer(),
  //                 Icon(Icons.bookmark_border, color: Colors.white),
  //               ],
  //             ),
  //             SizedBox(height: 8),
  //             Text('${post['likes']} likes',
  //                 style: TextStyle(
  //                     color: Colors.white, fontWeight: FontWeight.bold)),
  //             SizedBox(height: 4),
  //             RichText(
  //               text: TextSpan(
  //                 children: [
  //                   TextSpan(
  //                     text: '${post['username']} ',
  //                     style: TextStyle(
  //                       color: Colors.white,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //                   TextSpan(
  //                     text: post['caption'],
  //                     style: TextStyle(color: Colors.white),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             SizedBox(height: 4),
  //             Text(post['time'],
  //                 style: TextStyle(color: Colors.grey, fontSize: 12)),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildSearchScreen() {
    // Static list of image URLs (replace with your own or use AssetImage)
    final List<String> images = [
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
      'https://images.unsplash.com/photo-1465101046530-73398c7f28ca',
      'https://images.unsplash.com/photo-1519125323398-675f0ddb6308',
      'https://images.unsplash.com/photo-1508672019048-805c876b67e2',
      'https://images.unsplash.com/photo-1519985176271-adb1088fa94c',
      'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
      'https://images.unsplash.com/photo-1465101046530-73398c7f28ca',
      'https://images.unsplash.com/photo-1519125323398-675f0ddb6308',
      'https://images.unsplash.com/photo-1508672019048-805c876b67e2',
      'https://images.unsplash.com/photo-1519985176271-adb1088fa94c',
      'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
      'https://images.unsplash.com/photo-1465101046530-73398c7f28ca',
      'https://images.unsplash.com/photo-1519125323398-675f0ddb6308',
      'https://images.unsplash.com/photo-1508672019048-805c876b67e2',
      'https://images.unsplash.com/photo-1519985176271-adb1088fa94c',
      'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
      'https://images.unsplash.com/photo-1465101046530-73398c7f28ca',
      'https://images.unsplash.com/photo-1519125323398-675f0ddb6308',
      'https://images.unsplash.com/photo-1508672019048-805c876b67e2',
      'https://images.unsplash.com/photo-1519985176271-adb1088fa94c',
      'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
      // Add more if you like!
    ];
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextField(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchScreen(),
                    ),
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Ask Meta AI or Search',
                  hintStyle: TextStyle(color: Colors.grey[700]),
                  prefixIcon: Icon(
                    OIcons.Bootstrap.meta,
                    color: Colors.blue,
                    size: 25,
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                ),
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(3),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateScreen() {
    return SafeArea(
        child: Scaffold(
            appBar: AppBar(
      title: Text(
        "Create Post",
        style: TextStyle(color: Colors.white),
      ),
    )));
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

  Widget _buildProfileScreen() {
    return SafeArea(
        child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              leading: Icon(Icons.lock_outline, color: Colors.white),
              title: Text(
                "husain_19",
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                IconButton(
                    onPressed: () {},
                    icon: Icon(
                      OIcons.Bootstrap.threads,
                      color: Colors.white,
                    )),
                IconButton(
                    onPressed: () {},
                    icon: Image.asset(
                      "assets/images/add-square-button.png",
                      color: Colors.white,
                      width: 24,
                      height: 24,
                    )),
                IconButton(
                    onPressed: () {},
                    icon: Icon(
                      OIcons.ZondIcons.menu,
                      size: 28,
                      color: Colors.white,
                    ))
              ],
            ),
            body: SingleChildScrollView(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 17),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.grey, Colors.grey]),
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                            radius: 49,
                            backgroundColor: Colors.black,
                            child: CircleAvatar(
                              radius: 47,
                              backgroundColor: Colors.grey[800],
                              child: ClipOval(
                                child: Image.network(
                                  "https://picsum.photos/200",
                                  width: 93,
                                  height: 93,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )),
                      ),
                      SizedBox(width: 29),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Husain Rangwala",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                )),
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      "3",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                    Text(
                                      "posts",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: 30,
                                ),
                                Column(
                                  children: [
                                    Text(
                                      "290",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                    Text(
                                      "followers",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: 30,
                                ),
                                Column(
                                  children: [
                                    Text(
                                      "243",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                    Text(
                                      "following",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                  ],
                                )
                              ],
                            )
                          ]),
                    ],
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  child: Text(
                    "Flutter developer | Tech enthusiast | Traveler | Gamer | Learner | Creator | Designer",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                SizedBox(
                  height: 12,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          child: Text(
                            "Edit Profile",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Expanded(
                          child: OutlinedButton(
                        onPressed: () {},
                        child: Text(
                          "Share Profile",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                      )),
                    ],
                  ),
                ),
                SizedBox(
                  height: 30,
                ),
                Padding(
                  padding: EdgeInsets.zero,
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey,
                          tabs: [
                            Tab(
                              icon: Icon(OIcons.Bootstrap.grid_3x3_gap_fill),
                            ),
                            Tab(
                              icon: Icon(OIcons.OctIcons.mention),
                            )
                          ],
                        ),
                        SizedBox(
                          height: 400,
                          child: TabBarView(
                            children: [
                              GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3),
                                  itemCount: 20,
                                  itemBuilder: (context, index) {
                                    return Container(
                                        margin: EdgeInsets.all(1),
                                        decoration: BoxDecoration(
                                            image: DecorationImage(
                                              image: NetworkImage(
                                                  "https://picsum.photos/200"),
                                              fit: BoxFit.cover,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(1),
                                            color: Colors.grey));
                                  }),
                              GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3),
                                  itemCount: 20,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin: EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: NetworkImage(
                                                "https://picsum.photos/204"),
                                            fit: BoxFit.cover,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(1),
                                          color: Colors.grey),
                                    );
                                  })
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ]),
            )));
  }
}
