import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/notificationscreen/service/notification_service.dart';
import '../services/supabase_service.dart';

class InstaDataProvider extends ChangeNotifier {
  List<PostData> _posts = [];
  int _postsPage = 0;
  final int _postsPerPage = 5; // Fetch 5 posts at a time
  bool _hasMorePosts = true;
  bool _isLoadingPosts = false;
  bool _isLoading = false;
  UserData? _currentUser;
  List<StoryData> _stories = [];
  String? _error;
  Map<String, List<StoryData>> _allIndividualStoriesGrouped = {};
  List<PostData> _suggestedPosts = [];
  List<PostData> get suggestedPosts => _suggestedPosts;

  bool get isLoading => _isLoading;

  bool get isLoadingPosts => _isLoadingPosts;
  bool get hasMorePosts => _hasMorePosts;
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
    _postsPage = 0;
    _hasMorePosts = true;
    _isLoadingPosts = false;
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

      _posts = [];
      _postsPage = 0;
      _hasMorePosts = true;
      await _fetchPosts(); // Initial fetch

      // Load feed data in parallel
      await Future.wait([
        _fetchStories(),
        fetchSuggestedPosts(),
      ]);
      shufflePosts();
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

  // THIS METHOD IS REFACTORED for pagination
  Future<void> _fetchPosts() async {
    // Prevent multiple simultaneous fetches
    if (_isLoadingPosts || !_hasMorePosts) return;

    _isLoadingPosts = true;
    notifyListeners();

    try {
      // Use the new paginated service method
      final newPosts = await SupabaseService.getFeedPosts(
        page: _postsPage,
        pageSize: _postsPerPage,
      );

      if (newPosts.length < _postsPerPage) {
        _hasMorePosts = false;
      }

      _posts.addAll(newPosts);
      _postsPage++;

    } catch (e) {
      _error = 'Failed to load posts: $e';
    } finally {
      _isLoadingPosts = false;
      notifyListeners();
    }
  }

  // --- NEW public method to be called from the UI scroll listener ---
  Future<void> fetchMorePosts() async {
    await _fetchPosts();
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
          disableComments: json['disable_comments'] ?? false,
          use_original_ratio: json['use_original_ratio'],
          image_transformation: json['image_transformation'],
          original_aspect_ratio: (json['original_aspect_ratio'] as num?)?.toDouble() ?? 1.0,
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
          disableComments: post.disableComments,
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
    // Find the post in either the main list or suggested list
    int postIndex = _posts.indexWhere((p) => p.id == postId);
    List<PostData> sourceList = _posts;

    if (postIndex == -1) {
      postIndex = _suggestedPosts.indexWhere((p) => p.id == postId);
      sourceList = _suggestedPosts;
    }

    if (postIndex == -1) return; // Post not found

    final post = sourceList[postIndex];
    final isCurrentlyLiked = post.isLiked;
    final newLikeCount = isCurrentlyLiked ? post.likeCount - 1 : post.likeCount + 1;

    // Optimistic UI update: modify the post in-place
    sourceList[postIndex] = post.copyWith(
      isLiked: !isCurrentlyLiked,
      likeCount: newLikeCount,
    );
    notifyListeners();

    try {
      // Actual API call
      await SupabaseService.toggleLike(postId);
    } catch (e) {
      // Revert on error
      sourceList[postIndex] = post;
      notifyListeners();
      Fluttertoast.showToast(msg: "Error: Could not update like");
    }
  }

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
        disableComments: post.disableComments,
        use_original_ratio: post.use_original_ratio,
        image_transformation: post.image_transformation,
        original_aspect_ratio: post.original_aspect_ratio,
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
  // In your InstaDataProvider
  Future<List<PostData>> getSavedPosts() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];

      // 1. Get saved posts with nested post and user details (your efficient query)
      final response = await supabase
          .from('saved_posts')
          .select('''
          posts:post_id(
            id, user_id, caption, location, image_url, created_at,
            disable_comments, use_original_ratio, image_transformation, original_aspect_ratio,
            users:user_id(username, profile_image_url)
          )
        ''')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      // 2. Extract post IDs to fetch their likes and comments
      final postIds = response
          .map((item) => item['posts']?['id'])
          .where((id) => id != null)
          .toList();

      if (postIds.isEmpty) {
        return [];
      }

      // 3. Fetch all likes and comments for these posts in parallel for efficiency
      final [likesResponse, commentsResponse] = await Future.wait([
        supabase.from('post_likes').select('post_id, user_id').inFilter('post_id', postIds),
        supabase.from('comments').select('id, post_id').inFilter('post_id', postIds)
      ]);

      // 4. Process likes and comments into lookup maps for quick access
      final Map<String, List<dynamic>> likesByPost = {};
      for (final like in likesResponse as List) {
        final postId = like['post_id'].toString();
        likesByPost.putIfAbsent(postId, () => []).add(like);
      }

      final Map<String, List<dynamic>> commentsByPost = {};
      for (final comment in commentsResponse as List) {
        final postId = comment['post_id'].toString();
        commentsByPost.putIfAbsent(postId, () => []).add(comment);
      }

      // 5. Build the final list of PostData, now with accurate interaction data
      final List<PostData> savedPosts = [];
      for (final item in response) {
        final postData = item['posts'];
        if (postData != null) {
          final postId = postData['id'].toString();
          final likes = likesByPost[postId] ?? [];
          final comments = commentsByPost[postId] ?? [];
          final bool isLiked = likes.any((like) => like['user_id'] == currentUserId);

          // Construct the PostData object using the complete data
          // Note: This assumes your PostData class constructor matches the one used
          // in your current_user_profile.dart file.
          final post = PostData(
            id: postData['id'],
            userId: postData['user_id'],
            username: postData['users']?['username'] ?? 'Unknown',
            profileImageUrl: postData['users']?['profile_image_url'],
            imageUrl: postData['image_url'],
            caption: postData['caption'],
            location: postData['location'],
            createdAt: DateTime.tryParse(postData['created_at'] ?? '') ?? DateTime.now(),
            likeCount: likes.length,      // <-- Now using correct data
            commentCount: comments.length,// <-- Now using correct data
            isLiked: isLiked,             // <-- Now using correct data
            isSaved: true,
            disableComments: postData['disable_comments'] ?? false,
            use_original_ratio: postData['use_original_ratio'],
            image_transformation: postData['image_transformation'],
            original_aspect_ratio: (postData['original_aspect_ratio'] as num?)?.toDouble() ?? 1.0,
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

  // Add this method to your InstaDataProvider class
  void shufflePosts() {
    if (_posts.isNotEmpty) {
      _posts.shuffle(Random());
      notifyListeners();
    }
  }

  Future<String?> createStory(String mediaUrl, {String? sharedPostId}) async {
    try {
      // Pass the sharedPostId to the service method
      final response = await SupabaseService.createStory(mediaUrl, sharedPostId: sharedPostId);
      final storyId = response['id'] as String?;

      // --- The existing optimistic update logic ---
      final currentUserStoryIndex = _stories.indexWhere((story) => story.userId == _currentUser?.id);

      // ... (rest of the optimistic update logic remains the same)

      // Refresh data to ensure consistency
      await Future.delayed(const Duration(milliseconds: 1500)); // Allow time for DB to sync
      await _fetchStories();
      notifyListeners();

      print('InstaDataProvider: Story created and home screen refreshed.');
      return storyId;
    } catch (e) {
      print('Error creating story: $e');
      return null;
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
        likeCount: post.likeCount,
        commentCount: post.commentCount,
        isLiked: isLiked,
        isSaved: post.isSaved,
        disableComments: post.disableComments,
        use_original_ratio: post.use_original_ratio,
        image_transformation: post.image_transformation,
        original_aspect_ratio: post.original_aspect_ratio,
      );
    }

    // Also update in suggested posts list
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
        likeCount: isLiked ? post.likeCount + 1 : post.likeCount - 1,
        commentCount: post.commentCount,
        isLiked: isLiked,
        isSaved: post.isSaved,
        disableComments: post.disableComments,
        use_original_ratio: post.use_original_ratio,
        image_transformation: post.image_transformation,
        original_aspect_ratio: post.original_aspect_ratio,
      );
    }

    notifyListeners();
  }

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
        disableComments: post.disableComments,
        use_original_ratio: post.use_original_ratio,
        image_transformation: post.image_transformation,
        original_aspect_ratio: post.original_aspect_ratio,
      );
    }

    // Also update in suggested posts list
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
        isSaved: isSaved,
        disableComments: post.disableComments,
        use_original_ratio: post.use_original_ratio,
        image_transformation: post.image_transformation,
        original_aspect_ratio: post.original_aspect_ratio,
      );
    }

    notifyListeners();
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
            disableComments: post.disableComments,
            use_original_ratio: post.use_original_ratio,
            image_transformation: post.image_transformation,
            original_aspect_ratio: post.original_aspect_ratio,
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
            disableComments: post.disableComments,
            use_original_ratio: post.use_original_ratio,
            image_transformation: post.image_transformation,
            original_aspect_ratio: post.original_aspect_ratio,
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
