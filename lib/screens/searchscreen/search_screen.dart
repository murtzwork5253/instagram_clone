// search_screen.dart
import 'package:Instagram/screens/profilescreen/single_post_view.dart';
import 'package:Instagram/screens/searchscreen/search_screen_state.dart'; // This import seems unused, you might want to remove it if not needed.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;

import '../../services/supabase_service.dart'; // Make sure PostData is accessible from here

class InstagramSearchScreen extends StatefulWidget {
  // Add a refreshNotifier parameter
  final ValueNotifier<int>? refreshNotifier;

  const InstagramSearchScreen({Key? key, this.refreshNotifier}) : super(key: key);

  @override
  State<InstagramSearchScreen> createState() => _InstagramSearchScreenState();
}

class _InstagramSearchScreenState extends State<InstagramSearchScreen> {
  late Future<List<PostData>> _futurePosts; // Changed to PostData based on previous conversation.

  @override
  void initState() {
    super.initState();
    _futurePosts = _fetchExplorePosts(); // Changed to _fetchExplorePosts
    // Listen to the refresh notifier
    widget.refreshNotifier?.addListener(_onRefreshTriggered);
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed
    widget.refreshNotifier?.removeListener(_onRefreshTriggered);
    super.dispose();
  }

  // Method to handle the refresh triggered by the notifier
  void _onRefreshTriggered() {
    setState(() {
      _futurePosts = _fetchExplorePosts(); // Re-fetch posts
    });
  }


  Future<List<PostData>> _fetchExplorePosts() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    try {
      final postsResponse = await supabase
          .from('posts')
          .select('''
        id,
        user_id,
        caption,
        location,
        image_url,
        created_at,
        disable_comments,
        use_original_ratio,
        image_transformation,
        original_aspect_ratio,
        users (
          username,
          profile_image_url
        )
      ''')
          .order('created_at', ascending: false);

      // Get all post IDs to fetch likes, comments, and saves separately
      final postIds = (postsResponse as List).map((post) => post['id']).toList();

      // Fetch all likes for these posts
      final likesResponse = await supabase
          .from('post_likes')
          .select('post_id, user_id')
          .inFilter('post_id', postIds);

      // Fetch all comments for these posts
      final commentsResponse = await supabase
          .from('comments')
          .select('id, post_id')
          .inFilter('post_id', postIds);

      // Fetch saved posts for current user
      List<dynamic> savedResponse = [];
      if (userId != null) {
        savedResponse = await supabase
            .from('saved_posts')
            .select('post_id')
            .eq('user_id', userId)
            .inFilter('post_id', postIds);
      }

      // Group likes, comments, and saves by post_id
      final Map<String, List<dynamic>> likesByPost = {};
      final Map<String, List<dynamic>> commentsByPost = {};
      final Set<String> savedPostIds = savedResponse
          .map((save) => save['post_id'].toString())
          .toSet();

      for (final like in likesResponse as List) {
        final postId = like['post_id'].toString();
        likesByPost[postId] = (likesByPost[postId] ?? [])..add(like);
      }

      for (final comment in commentsResponse as List) {
        final postId = comment['post_id'].toString();
        commentsByPost[postId] = (commentsByPost[postId] ?? [])..add(comment);
      }

      return (postsResponse).map((post) {
        final user = post['users'];
        final postId = post['id'].toString();
        final likes = likesByPost[postId] ?? [];
        final comments = commentsByPost[postId] ?? [];

        final bool isLiked = userId != null
            ? likes.any((like) => like['user_id'] == userId)
            : false;

        return PostData(
          id: post['id'],
          userId: post['user_id'],
          username: user['username'],
          profileImageUrl: user['profile_image_url'],
          imageUrl: post['image_url'],
          caption: post['caption'],
          location: post['location'],
          createdAt: DateTime.parse(post['created_at']),
          likeCount: likes.length,
          commentCount: comments.length,
          isLiked: isLiked,
          isSaved: savedPostIds.contains(postId),
          disableComments: post['disable_comments'] ?? false,
          use_original_ratio: post['use_original_ratio'],
          image_transformation: post['image_transformation'],
          original_aspect_ratio: (post['original_aspect_ratio'] as num?)?.toDouble() ?? 1.0,
        );
      }).toList();
    } catch (e) {
      print('Error fetching posts for explore feed: $e');
      return [];
    }
  }

  // Renamed _refreshImages to _refreshPosts for consistency with _fetchExplorePosts
  Future<void> _refreshPosts() async {
    setState(() {
      _futurePosts = _fetchExplorePosts();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      builder: (context) =>
                          SearchScreen(), // Assuming you have a detailed SearchScreen
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
                readOnly: true, // Makes it act as a button
              ),
            ),
            Expanded(
              child: FutureBuilder<List<PostData>>( // Changed to PostData
                future: _futurePosts,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading posts: ${snapshot.error}', // Changed text
                          style: const TextStyle(color: Colors.white)),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No posts found', // Changed text
                          style: TextStyle(color: Colors.white)),
                    );
                  }

                  final posts = snapshot.data!; // Changed to posts

                  return RefreshIndicator(
                    onRefresh: _refreshPosts, // Changed to _refreshPosts
                    child: GridView.builder(
                      padding: const EdgeInsets.all(3),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                      ),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index]; // Get the PostData object
                        final mediaUrl = post.imageUrl.toString().startsWith('http')
                            ? post.imageUrl
                            : Supabase.instance.client.storage
                            .from('post-media')
                            .getPublicUrl(post.imageUrl);
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SinglePostView(
                                  posts: posts, // Pass the PostData object
                                  initialIndex: index,
                                  Url: post.profileImageUrl ?? '', // Pass profile image URL
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'searchImage_${post.id}', // Use post.id for unique tag
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: Image.network(
                                mediaUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[900],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                            .expectedTotalBytes !=
                                            null
                                            ? loadingProgress
                                            .cumulativeBytesLoaded /
                                            loadingProgress
                                                .expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.error, color: Colors.white),
                                    ),
                              ),
                            ),
                          ),
                        );
                      },
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
}