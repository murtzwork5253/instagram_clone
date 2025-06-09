import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class InstaDataProvider extends ChangeNotifier {
  bool _isLoading = false;
  UserData? _currentUser;
  List<PostData> _posts = [];
  List<StoryData> _stories = [];
  String? _error;
  // NEW: Map to store all individual stories, grouped by user ID
  // This will be used when navigating to StoryViewScreen
  Map<String, List<StoryData>> _allIndividualStoriesGrouped = {};
  List<PostData> _suggestedPosts = [];
  List<PostData> get suggestedPosts => _suggestedPosts;

  bool get isLoading => _isLoading;

  UserData? get currentUser => _currentUser;

  List<PostData> get posts => _posts;

  List<StoryData> get stories => _stories;

  String? get error => _error;

  InstaDataProvider() {
    reloadData();
  }

  void reset() {
    _currentUser = null;
    _posts = [];
    _stories = [];
    _error = null;
    notifyListeners();
  }

  Future<void> reloadData() async {
    setLoading(true);
    _error = null;

    try {
      // Load essential user data first
      await _fetchCurrentUser();

      if (_currentUser == null) {
        _error = "User not authenticated";
        setLoading(false);
        return;
      }

      // Load feed data in parallel
      await Future.wait([
        _fetchPosts(),
        _fetchStories(),
      ]);
      await fetchSuggestedPosts();
    } catch (e) {
      _error = e.toString();
      print('Error loading data: $_error');
    } finally {
      setLoading(false);
    }
  }

  // Add this method to InstaDataProvider class

  Future<void> reloadProfileData() async {
    setLoading(true);
    _error = null;

    try {
      // Only reload current user data since profile screen shows current user's data
      await _fetchCurrentUser();

      if (_currentUser == null) {
        _error = "User not authenticated";
        setLoading(false);
        return;
      }

      print('Profile data reloaded for user: ${_currentUser!.username}');
    } catch (e) {
      _error = e.toString();
      print('Error reloading profile data: $_error');
    } finally {
      setLoading(false);
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> _fetchCurrentUser() async {
    try {
      _currentUser = await SupabaseService.getCurrentUser();
      print('Current user fetched: ${_currentUser?.username ?? "null"}');
      notifyListeners();
    } catch (e) {
      print('Error fetching current user: $e');
      _error = 'Failed to load user data';
    }
  }

  Future<void> _fetchPosts() async {
    try {
      final posts = await SupabaseService.getFeedPosts();

      // Get current user ID
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (currentUserId != null) {
        // Get all saved post IDs for current user
        final savedPostsResponse = await Supabase.instance.client
            .from('saved_posts')
            .select('post_id')
            .eq('user_id', currentUserId);

        final savedPostIds = savedPostsResponse
            .map((item) => item['post_id'] as String)
            .toSet();

        // Update posts with saved status
        _posts = posts.map((post) => PostData(
          id: post.id,
          userId: post.userId,
          username: post.username,
          profileImageUrl: post.profileImageUrl,
          imageUrl: post.imageUrl,
          caption: post.caption,
          location: post.location,
          createdAt: post.createdAt,
          likeCount: post.likeCount,
          commentCount: post.commentCount,
          isLiked: post.isLiked,
          isSaved: savedPostIds.contains(post.id),
        )).toList();
      } else {
        _posts = posts;
      }

      notifyListeners();
    } catch (e) {
      print('Error fetching posts: $e');
      _error = 'Failed to load posts';
      notifyListeners();
    }
  }

  // Method to fetch suggested posts
  Future<void> fetchSuggestedPosts() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // First, get the list of users that current user is following
      final followingResponse = await Supabase.instance.client
          .from('followers')
          .select('following_id')
          .eq('follower_id', currentUserId);

      // Extract the following IDs
      final followingIds = followingResponse
          .map((row) => row['following_id'] as String)
          .toList();

      // Add current user ID to exclude their own posts
      followingIds.add(currentUserId);

      // Get posts with user profile data
      final response = await Supabase.instance.client
          .from('posts')
          .select('''
        *,
        users:user_id(username, profile_image_url)
      ''')
          .not('user_id', 'in', '(${followingIds.join(',')})')
          .order('created_at', ascending: false)
          .limit(10);

      _suggestedPosts = [];

      // Get all post IDs for batch operations
      final postIds = (response as List).map((json) => json['id'] as String).toList();

      if (postIds.isEmpty) {
        notifyListeners();
        return;
      }

      // Get like counts for all posts in batch
      final allLikesResponse = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .inFilter('post_id', postIds);

      // Get comment counts for all posts in batch
      final allCommentsResponse = await Supabase.instance.client
          .from('comments')
          .select('post_id')
          .inFilter('post_id', postIds);

      // Check which posts current user has liked
      final userLikesResponse = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', currentUserId)
          .inFilter('post_id', postIds);

      // Create maps for quick lookup
      final likeCounts = <String, int>{};
      final commentCounts = <String, int>{};
      final likedPostIds = <String>{};

      // Count likes per post
      for (final like in allLikesResponse) {
        final postId = like['post_id'].toString();
        likeCounts[postId] = (likeCounts[postId] ?? 0) + 1;
      }

      // Count comments per post
      for (final comment in allCommentsResponse) {
        final postId = comment['post_id'].toString();
        commentCounts[postId] = (commentCounts[postId] ?? 0) + 1;
      }

      // Track user's liked posts
      for (final like in userLikesResponse) {
        likedPostIds.add(like['post_id'].toString());
      }

      for (final json in response) {
        final postId = json['id'].toString();
        final likeCount = likeCounts[postId] ?? 0;
        final commentCount = commentCounts[postId] ?? 0;
        final isLiked = likedPostIds.contains(postId);

        // Create PostData with all required parameters
        final post = PostData(
          id: json['id'],
          userId: json['user_id'],
          username: json['users']?['username'] ?? 'Unknown',
          profileImageUrl: json['users']?['profile_image_url'],
          imageUrl: json['image_url'],
          caption: json['caption'],
          location: json['location'],
          createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
          likeCount: likeCount,
          isLiked: isLiked,
          commentCount: commentCount,
        );

        _suggestedPosts.add(post);
      }

      if (_suggestedPosts.isNotEmpty) {
        final postIds = _suggestedPosts.map((post) => post.id).toList();

        final savedPostsResponse = await Supabase.instance.client
            .from('saved_posts')
            .select('post_id')
            .eq('user_id', currentUserId)
            .inFilter('post_id', postIds);

        final savedPostIds = savedPostsResponse
            .map((item) => item['post_id'] as String)
            .toSet();

        // Update suggested posts with saved status
        _suggestedPosts = _suggestedPosts.map((post) => PostData(
          id: post.id,
          userId: post.userId,
          username: post.username,
          profileImageUrl: post.profileImageUrl,
          imageUrl: post.imageUrl,
          caption: post.caption,
          location: post.location,
          createdAt: post.createdAt,
          likeCount: post.likeCount,
          commentCount: post.commentCount,
          isLiked: post.isLiked,
          isSaved: savedPostIds.contains(post.id),
        )).toList();
      }

      notifyListeners();
    } catch (e) {
      print('Error fetching suggested posts: $e');
    }
  }

  // In your provider or service class
  Future<void> followUser1(String userIdToFollow) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Add the follow relationship
      await Supabase.instance.client.from('followers').insert({
        'follower_id': currentUserId,
        'following_id': userIdToFollow,
      });

      // Refresh both regular posts and suggested posts
      await Future.wait([
        _fetchPosts(), // Refresh regular posts to include new followed user
        fetchSuggestedPosts(), // Refresh suggested posts to exclude the followed user
      ]);

      notifyListeners();
    } catch (e) {
      print('Error following user: $e');
    }
  }

  Future<void> unfollowUser1(String userIdToUnfollow) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Remove the follow relationship
      await Supabase.instance.client
          .from('followers')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', userIdToUnfollow);

      // Refresh both regular posts and suggested posts
      await Future.wait([
        _fetchPosts(), // Refresh regular posts to exclude unfollowed user
        fetchSuggestedPosts(), // Refresh suggested posts to include the unfollowed user
      ]);

      notifyListeners();
    } catch (e) {
      print('Error unfollowing user: $e');
    }
  }


  // Future<void> _fetchStories() async {
  //   try {
  //     print('Fetching stories...');
  //     final fetchedStories = await SupabaseService.getStories();
  //     // ADD THIS PRINT STATEMENT:
  //     final currentUserAggregatedStory = fetchedStories.firstWhere(
  //             (story) => story.userId == _currentUser?.id,
  //         orElse: () => StoryData(id: '', userId: '', username: 'N/A', profileImageUrl: '', mediaUrl: '', isMe: false, hasStory: false, isViewed: false, createdAt: DateTime.now()) // Default for safety
  //     );
  //     print('InstaDataProvider - Current User Aggregated Story isViewed: ${currentUserAggregatedStory.isViewed}');
  //     _stories = fetchedStories;
  //     notifyListeners();
  //   } catch (e) {
  //     print('Error fetching stories: $e');
  //     // Don't set error for stories as it's not critical
  //   }
  // }

  // --- MODIFIED _fetchStories() METHOD ---
  // Optimized version of _fetchStories() with better performance and cleaner logic
  Future<void> _fetchStories() async {
    try {
      print('Fetching stories...');

      // 1. Fetch all individual stories from Supabase
      final fetchedStories = await SupabaseService.getStories();

      // 2. Update the grouped stories cache for StoryViewScreen
      _updateIndividualStoriesCache(fetchedStories);

      // 3. Process stories into aggregated format
      final processedStories = _processStoriesToAggregated(fetchedStories);

      // 4. Ensure current user appears first and handle empty story case
      final finalStories = _ensureCurrentUserInStories(processedStories);

      print("🧾 Final processed stories: ${finalStories.map((s) => '${s.username}: hasStory=${s.hasStory}, isMe=${s.isMe}, isViewed=${s.isViewed}').toList()}");

      _stories = finalStories;
      notifyListeners();
      print('InstaDataProvider: Stories fetched and aggregated successfully.');

    } catch (e) {
      _error = 'Failed to fetch stories: $e';
      print('Error fetching stories: $e');
      notifyListeners();
    }
  }

  void _updateIndividualStoriesCache(List<StoryData> fetchedStories) {
    _allIndividualStoriesGrouped.clear();
    for (final story in fetchedStories) {
      _allIndividualStoriesGrouped.putIfAbsent(story.userId, () => []).add(story);
    }
  }

  List<StoryData> _processStoriesToAggregated(List<StoryData> fetchedStories) {
    // Group stories by userId
    final Map<String, List<StoryData>> groupedStories = {};
    for (final story in fetchedStories) {
      groupedStories.putIfAbsent(story.userId, () => []).add(story);
    }

    final List<StoryData> processedStories = [];

    for (final entry in groupedStories.entries) {
      final userId = entry.key;
      final userStories = entry.value;

      // Sort stories by creation time
      userStories.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

      final hasAnyStory = userStories.isNotEmpty;
      final hasUnviewedStories = userStories.any((story) => !story.isViewed);
      final representativeStory = userStories.first;

      // Create aggregated story data
      final aggregatedStory = StoryData(
        id: representativeStory.id,
        userId: userId,
        username: representativeStory.username,
        profileImageUrl: representativeStory.profileImageUrl,
        mediaUrl: representativeStory.mediaUrl,
        isMe: userId == _currentUser?.id,
        hasStory: hasAnyStory,
        isViewed: !hasUnviewedStories,
        createdAt: representativeStory.createdAt,
      );

      processedStories.add(aggregatedStory);
    }

    return processedStories;
  }

  List<StoryData> _ensureCurrentUserInStories(List<StoryData> processedStories) {
    // Check if current user is already in the list
    final currentUserExists = processedStories.any((story) => story.userId == _currentUser?.id);

    if (!currentUserExists && _currentUser != null) {
      print('🚨 Adding placeholder story for current user: ${_currentUser!.username}');

      final emptyStory = StoryData(
        id: '',
        userId: _currentUser!.id,
        username: _currentUser!.username,
        profileImageUrl: _currentUser!.profileImageUrl,
        mediaUrl: '',
        isMe: true,
        hasStory: false,
        isViewed: false,
        createdAt: DateTime.now(),
      );

      processedStories.insert(0, emptyStory);
      print("✅ Added empty story for current user");
    }

    // Sort to ensure current user appears first
    if (_currentUser != null) {
      processedStories.sort((a, b) {
        if (a.userId == _currentUser!.id) return -1;
        if (b.userId == _currentUser!.id) return 1;
        return 0;
      });
    }

    return processedStories;
  }

  // NEW: Getter to provide individual stories for a specific user
  List<StoryData> getIndividualStoriesForUser(String userId) {
    return _allIndividualStoriesGrouped[userId] ?? [];
  }

  Future<void> refreshFeed() async {
    setLoading(true);
    _error = null;

    try {
      // Always fetch fresh data from the server to ensure counts are up-to-date
      await Future.wait([
        _fetchCurrentUser(),
        _fetchPosts(),
        _fetchStories(),
      ]);
    } catch (e) {
      _error = e.toString();
      print('Error refreshing feed: $_error');
    } finally {
      setLoading(false);
    }
  }

  Future<void> likePost(String postId) async {
    try {
      // Optimistic update
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final post = _posts[index];
        final newPosts = List<PostData>.from(_posts);
        newPosts[index] = PostData(
          id: post.id,
          userId: post.userId,
          username: post.username,
          profileImageUrl: post.profileImageUrl,
          imageUrl: post.imageUrl,
          caption: post.caption,
          location: post.location,
          createdAt: post.createdAt,
          likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
          commentCount: post.commentCount,
          isLiked: !post.isLiked,
        );
        _posts = newPosts;
        notifyListeners();
      }

      // Actual API call
      final isLiked = await SupabaseService.toggleLike(postId);

      // Update UI with actual state if needed (usually not necessary if optimistic update worked)
      final updatedIndex = _posts.indexWhere((post) => post.id == postId);
      if (updatedIndex != -1) {
        final post = _posts[updatedIndex];
        if (post.isLiked != isLiked) {
          final newPosts = List<PostData>.from(_posts);
          newPosts[updatedIndex] = PostData(
            id: post.id,
            userId: post.userId,
            username: post.username,
            profileImageUrl: post.profileImageUrl,
            imageUrl: post.imageUrl,
            caption: post.caption,
            location: post.location,
            createdAt: post.createdAt,
            likeCount: isLiked ? post.likeCount + 1 : post.likeCount - 1,
            commentCount: post.commentCount,
            isLiked: isLiked,
          );
          _posts = newPosts;
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error in likePost: $e");
      Fluttertoast.showToast(msg: "Error toggling like");
      // Refresh feed to get correct state
      refreshFeed();
    }
  }

  // Add these methods to your InstaDataProvider class

// Method to check if a post is saved by current user
  Future<bool> isPostSaved(String postId) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return false;

      final response = await Supabase.instance.client
          .from('saved_posts')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('post_id', postId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking if post is saved: $e');
      return false;
    }
  }

// Method to save a post
  Future<void> savePost(String postId) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        Fluttertoast.showToast(msg: "User not authenticated");
        return;
      }

      // Check if post is already saved
      final isAlreadySaved = await isPostSaved(postId);
      if (isAlreadySaved) {
        Fluttertoast.showToast(msg: "Post already saved");
        return;
      }

      // Save the post
      await Supabase.instance.client.from('saved_posts').insert({
        'user_id': currentUserId,
        'post_id': postId,
      });

      // Update local state - find the post and update its saved status
      _updatePostSavedStatus(postId, true);

      Fluttertoast.showToast(msg: "Post saved successfully");
      notifyListeners();
    } catch (e) {
      print('Error saving post: $e');
      Fluttertoast.showToast(msg: "Error saving post");
    }
  }

// Method to unsave a post
  Future<void> unsavePost(String postId) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        Fluttertoast.showToast(msg: "User not authenticated");
        return;
      }

      // Remove the saved post
      await Supabase.instance.client
          .from('saved_posts')
          .delete()
          .eq('user_id', currentUserId)
          .eq('post_id', postId);

      // Update local state
      _updatePostSavedStatus(postId, false);

      Fluttertoast.showToast(msg: "Post removed from saved");
      notifyListeners();
    } catch (e) {
      print('Error unsaving post: $e');
      Fluttertoast.showToast(msg: "Error removing post from saved");
    }
  }

// Method to toggle save/unsave
  Future<void> toggleSavePost(String postId) async {
    try {
      final isSaved = await isPostSaved(postId);
      if (isSaved) {
        await unsavePost(postId);
      } else {
        await savePost(postId);
      }
    } catch (e) {
      print('Error toggling save post: $e');
      Fluttertoast.showToast(msg: "Error updating post save status");
    }
  }

// Helper method to update post saved status in local state
  void _updatePostSavedStatus(String postId, bool isSaved) {
    // Update in main posts list
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index != -1) {
      final post = _posts[index];
      _posts[index] = PostData(
        id: post.id,
        userId: post.userId,
        username: post.username,
        profileImageUrl: post.profileImageUrl,
        imageUrl: post.imageUrl,
        caption: post.caption,
        location: post.location,
        createdAt: post.createdAt,
        likeCount: post.likeCount,
        commentCount: post.commentCount,
        isLiked: post.isLiked,
        isSaved: isSaved, // Add this field
      );
    }

    // Update in suggested posts list
    final suggestedIndex = _suggestedPosts.indexWhere((post) => post.id == postId);
    if (suggestedIndex != -1) {
      final post = _suggestedPosts[suggestedIndex];
      _suggestedPosts[suggestedIndex] = PostData(
        id: post.id,
        userId: post.userId,
        username: post.username,
        profileImageUrl: post.profileImageUrl,
        imageUrl: post.imageUrl,
        caption: post.caption,
        location: post.location,
        createdAt: post.createdAt,
        likeCount: post.likeCount,
        commentCount: post.commentCount,
        isLiked: post.isLiked,
        isSaved: isSaved, // Add this field
      );
    }
  }

// Method to get saved posts for current user
  Future<List<PostData>> getSavedPosts() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      // Get saved posts with post details and user profile
      final response = await Supabase.instance.client
          .from('saved_posts')
          .select('''
          created_at,
          posts:post_id(
            *,
            users:user_id(username, profile_image_url)
          )
        ''')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      final List<PostData> savedPosts = [];

      for (final item in response) {
        final postData = item['posts'];
        if (postData != null) {
          final post = PostData(
            id: postData['id'],
            userId: postData['user_id'],
            username: postData['users']?['username'] ?? 'Unknown',
            profileImageUrl: postData['users']?['profile_image_url'],
            imageUrl: postData['image_url'],
            caption: postData['caption'],
            location: postData['location'],
            createdAt: DateTime.tryParse(postData['created_at'] ?? '') ?? DateTime.now(),
            likeCount: 0, // You might want to fetch this separately
            commentCount: 0, // You might want to fetch this separately
            isLiked: false, // You might want to fetch this separately
            isSaved: true, // Always true for saved posts
          );
          savedPosts.add(post);
        }
      }

      return savedPosts;
    } catch (e) {
      print('Error fetching saved posts: $e');
      return [];
    }
  }

  Future<void> addComment(String postId, String content) async {
    try {
      await SupabaseService.addComment(postId, content);

      // Update comment count in local state
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final post = _posts[index];
        final newPosts = List<PostData>.from(_posts);
        newPosts[index] = PostData(
          id: post.id,
          userId: post.userId,
          username: post.username,
          profileImageUrl: post.profileImageUrl,
          imageUrl: post.imageUrl,
          caption: post.caption,
          location: post.location,
          createdAt: post.createdAt,
          likeCount: post.likeCount,
          commentCount: post.commentCount + 1,
          isLiked: post.isLiked,
        );
        _posts = newPosts;
        notifyListeners();
      }

      // Force a refresh to make sure server and client are in sync
      await Future.delayed(Duration(milliseconds: 500));
      refreshFeed();
    } catch (e) {
      Fluttertoast.showToast(msg: "Error Adding Comment");
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      // 1. Delete all associated likes for this comment from the 'comment_likes' table.
      // This ensures data integrity. We delete based only on comment_id,
      // as all likes for the deleted comment should be removed, regardless of who liked them.
      await Supabase.instance.client
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId);

      // 2. Now, delete the comment itself from the 'comments' table.
      // The user_id condition is to ensure that only the owner of the comment can delete it.
      await Supabase.instance.client
          .from('comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', _currentUser!.id); // Assuming _currentUser is available and not null

      refreshFeed(); // Refresh the feed to reflect the changes in the UI
    } catch (e) {
      print('Error deleting comment: $e'); // Add print for debugging
      Fluttertoast.showToast(msg: "Error Deleting Comment");
    }
  }

  Future<void> createPost({
    required String imageUrl,
    required String caption,
    String? location,
  }) async {
    try {
      await SupabaseService.createPost(
        imageUrl: imageUrl,
        caption: caption,
        location: location,
      );
      // Refresh feed to show the new post
      refreshFeed();

      Fluttertoast.showToast(msg: "Post Created Successfully");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error Creating Post");
    }
  }

  Future<Map<String, List<String>>> getCommentLikesMap(String postId) async {
    final supabaseService = SupabaseService();
    final data = await supabaseService.getCommentLikes(postId);
    final Map<String, List<String>> likesMap = {};

    for (final row in data) {
      final commentId = row['comment_id'] as String;
      final userId = row['user_id'] as String;

      likesMap.putIfAbsent(commentId, () => []);
      likesMap[commentId]!.add(userId);
    }

    return likesMap;
  }

  Future<bool> isFollowingUser(String currentUserId, String targetUserId) async {
    try {
      final response = await Supabase.instance.client
          .from('followers')
          .select('id')
          .eq('following_id', targetUserId)
          .eq('follower_id', currentUserId)
          .maybeSingle();

      return response != null; // Assume response is a boolean indicating the relationship
    } catch (e) {
      print('Error checking following status: $e');
      return false; // Return false if an exception occurs
    }
  }

  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      await Supabase.instance.client.from('followers').insert({
        'following_id': targetUserId,
        'follower_id': currentUserId,
      });
      notifyListeners();
    }
    catch(e){
      print('Error following user: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      await Supabase.instance.client
          .from('followers')
          .delete()
          .eq('following_id', targetUserId)
          .eq('follower_id', currentUserId);

      notifyListeners();
    }
    catch(e) {
      print('Error unfollowing user: $e');
      rethrow;
    }
  }

  Future<void> deletePost(String postId, String mediaPath) async {
    final result = await SupabaseService().deletePost(postId, mediaPath);

    if (result) {
      _posts.removeWhere((post) => post.id == postId);
      notifyListeners();
    } else {
      throw Exception('Failed to delete post');
    }
  }

  Future<void> createStory(String mediaUrl) async {
    try {
      // NEW CODE - Replace the above section with this:
      await SupabaseService.createStory(mediaUrl);

      // --- Start of refined optimistic update logic ---
      final currentUserStoryIndex = _stories.indexWhere((story) => story.userId == _currentUser?.id);

      if (currentUserStoryIndex != -1) {
        // If current user already has a story entry, update it to reflect the new unviewed story.
        final existingStory = _stories[currentUserStoryIndex];
        _stories[currentUserStoryIndex] = StoryData(
          id: existingStory.id,
          userId: existingStory.userId,
          username: existingStory.username,
          profileImageUrl: existingStory.profileImageUrl,
          mediaUrl: mediaUrl, // Use the new media URL
          isMe: true,
          hasStory: true, // User now definitively has a story
          isViewed: false, // Mark as unviewed because a new story was added
          createdAt: DateTime.now(), // Update creation time
        );
      } else {
        // If current user had no story entry (e.g., this is their very first story), create a new one.
        if (_currentUser != null) {
          _stories.insert(0, StoryData( // Insert at the beginning for typical display order
            id: 'new_story_temp_${DateTime.now().microsecondsSinceEpoch}', // Provide a temporary unique ID
            userId: _currentUser!.id,
            username: _currentUser!.username,
            profileImageUrl: _currentUser!.profileImageUrl, // Assuming avatarUrl is available in UserData
            mediaUrl: mediaUrl,
            isMe: true,
            hasStory: true,
            isViewed: false, // Mark as unviewed
            createdAt: DateTime.now(),
          ));
        }
      }
      notifyListeners(); // Notify listeners immediately after this optimistic local state update

      // --- End of refined optimistic update logic ---

      // Introduce a small delay to allow Supabase to synchronize data.
      await Future.delayed(const Duration(milliseconds: 5000));

      // Fetch stories from the server to ensure full consistency and handle any backend-determined state.
      await _fetchStories();
      notifyListeners(); // Notify again after fetching from DB to ensure the latest state is reflected

      print('InstaDataProvider: Story created and home screen refreshed.');
    } catch (e) {
      print('Error creating story: $e'); // Add this print for better error visibility
      // Fluttertoast.showToast(msg: "Error Creating Story");
    }
  }

  Future<void> viewStory(String storyId, String storyUserId) async {
    try {
      // 1. Attempt to mark the story as viewed in the database.
      // The local UI update will only happen if this is successful.
      await SupabaseService.markStoryAsViewed(storyId, storyOwnerId: storyUserId);

      // 2. If the database call succeeds, then update the viewed status locally.
      final index = _stories.indexWhere((story) => story.id == storyId);
      if (index != -1) {
        final newStories = List<StoryData>.from(_stories);
        final story = newStories[index];
        newStories[index] = StoryData(
          id: story.id,
          userId: story.userId,
          username: story.username,
          profileImageUrl: story.profileImageUrl,
          mediaUrl: story.mediaUrl,
          isMe: story.isMe,
          hasStory: story.hasStory,
          isViewed: true, // Mark as viewed only after successful DB write
          createdAt: story.createdAt,
        );
        _stories = newStories;
        notifyListeners(); // Notify listeners to update the UI (border changes to grey)
        print('Story $storyId locally marked as viewed after successful DB write.');
      }
    } on PostgrestException catch (e) {
      // Handle Supabase specific errors (like RLS violations)
      print('Database Error marking story as viewed: ${e.message}');
    } catch (e) {
      // Handle any other unexpected errors
      print('Generic Error marking story as viewed: ${e.toString()}');
      Fluttertoast.showToast(
        msg: "An unexpected error occurred. Could not mark story as viewed.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      // Do NOT update local state if DB write failed
    }
  }

  // Add these methods to your InstaDataProvider class:

// Helper method to handle like updates for explore posts
  void updateExplorePostLike(String postId, bool isLiked) {
    // Try to find and update the post in the current posts list
    final postIndex = _posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = _posts[postIndex];
      _posts[postIndex] = PostData(
        id: post.id,
        userId: post.userId,
        username: post.username,
        profileImageUrl: post.profileImageUrl,
        imageUrl: post.imageUrl,
        caption: post.caption,
        location: post.location,
        createdAt: post.createdAt,
        likeCount: isLiked ? post.likeCount + 1 : post.likeCount - 1,
        commentCount: post.commentCount,
        isLiked: isLiked,
        isSaved: post.isSaved,
      );
      notifyListeners();
    }
  }

// Helper method to handle save updates for explore posts
  void updateExplorePostSave(String postId, bool isSaved) {
    // Try to find and update the post in the current posts list
    final postIndex = _posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = _posts[postIndex];
      _posts[postIndex] = PostData(
        id: post.id,
        userId: post.userId,
        username: post.username,
        profileImageUrl: post.profileImageUrl,
        imageUrl: post.imageUrl,
        caption: post.caption,
        location: post.location,
        createdAt: post.createdAt,
        likeCount: post.likeCount,
        commentCount: post.commentCount,
        isLiked: post.isLiked,
        isSaved: isSaved,
      );
      notifyListeners();
    }
  }

// Enhanced like method that works for both feed and explore posts
  Future<void> searchLikePost(String postId) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if already liked
      final existingLike = await supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike the post
        await supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);

        // Update local post if it exists in the feed
        final postIndex = _posts.indexWhere((post) => post.id == postId);
        if (postIndex != -1) {
          final post = _posts[postIndex];
          _posts[postIndex] = PostData(
            id: post.id,
            userId: post.userId,
            username: post.username,
            profileImageUrl: post.profileImageUrl,
            imageUrl: post.imageUrl,
            caption: post.caption,
            location: post.location,
            createdAt: post.createdAt,
            likeCount: post.likeCount - 1,
            commentCount: post.commentCount,
            isLiked: false,
            isSaved: post.isSaved,
          );
        }
      } else {
        // Like the post
        await supabase
            .from('post_likes')
            .insert({
          'post_id': postId,
          'user_id': userId,
        });

        // Update local post if it exists in the feed
        final postIndex = _posts.indexWhere((post) => post.id == postId);
        if (postIndex != -1) {
          final post = _posts[postIndex];
          _posts[postIndex] = PostData(
            id: post.id,
            userId: post.userId,
            username: post.username,
            profileImageUrl: post.profileImageUrl,
            imageUrl: post.imageUrl,
            caption: post.caption,
            location: post.location,
            createdAt: post.createdAt,
            likeCount: post.likeCount + 1,
            commentCount: post.commentCount,
            isLiked: true,
            isSaved: post.isSaved,
          );
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error liking/unliking post: $e');
      throw e;
    }
  }
}
