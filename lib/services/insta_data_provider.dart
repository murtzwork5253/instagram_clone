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
    } catch (e) {
      _error = e.toString();
      print('Error loading data: $_error');
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
      _posts = posts;
      notifyListeners();
    } catch (e) {
      print('Error fetching posts: $e');
      _error = 'Failed to load posts';
      notifyListeners();
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
  Future<void> _fetchStories() async {
    try {
      print('Fetching stories...');
      // 1. Fetch all individual stories from Supabase
      final fetchedStories = await SupabaseService.getStories();

      // NEW: Store all individual stories grouped by user for direct access by StoryViewScreen
      _allIndividualStoriesGrouped.clear(); // Clear previous data
      for (final story in fetchedStories) {
        _allIndividualStoriesGrouped.putIfAbsent(story.userId, () => []).add(story);
      }

      // 2. Group individual stories by userId for aggregation into _stories
      final Map<String, List<StoryData>> groupedStories = {};
      for (final story in fetchedStories) {
        groupedStories.putIfAbsent(story.userId, () => []).add(story);
      }


      print('🪪 Checking if current user has stories in fetched list: ${fetchedStories.any((s) => s.userId == _currentUser?.id)}');

      // 3. Process each user's group of stories into a single, aggregated StoryData object
      final List<StoryData> processedStories = [];
      for (final entry in groupedStories.entries) {
        final userId = entry.key;
        final userIndividualStories = entry.value; // List of individual stories for this specific user

        // Sort stories for this user by creation time (oldest first for display order in StoryViewScreen)
        userIndividualStories.sort((a, b) => a.createdAt!.compareTo(b.createdAt!)); // Sort ascending for view order

        final bool hasAnyStory = userIndividualStories.isNotEmpty;
        final bool userHasUnviewedStories = userIndividualStories.any((story) => !story.isViewed);

        // Pick a representative story from the user's collection for the aggregated object
        final StoryData representativeIndividualStory = userIndividualStories.first; // Using the first story as representative for properties

        // Create the single aggregated StoryData object for this user
        final aggregatedStoryData = StoryData(
          id: representativeIndividualStory.id,
          userId: userId,
          username: representativeIndividualStory.username,
          profileImageUrl: representativeIndividualStory.profileImageUrl,
          mediaUrl: representativeIndividualStory.mediaUrl, // Media URL of the representative story
          isMe: userId == _currentUser?.id,
          hasStory: hasAnyStory,
          isViewed: !userHasUnviewedStories,
          createdAt: representativeIndividualStory.createdAt,
        );
        processedStories.add(aggregatedStoryData);
      }
      // 3.1 Handle the current user if they have no stories at all
      final bool currentUserAlreadyIncluded = processedStories.any((story) => story.userId == _currentUser?.id);
      if (!currentUserAlreadyIncluded && _currentUser != null) {
        print('🚨 Inserting placeholder story for current user: ${_currentUser!.username}');
        final emptyStory = StoryData(
          id: '',
          userId: _currentUser!.id,
          username: _currentUser!.username,
          profileImageUrl: _currentUser!.profileImageUrl,
          mediaUrl: '',
          isMe: true,
          hasStory: false,
          isViewed: true,
          createdAt: DateTime.now(),
        );
        processedStories.insert(0, emptyStory);
        print("✅ Inserted empty story for current user: hasStory=${emptyStory.hasStory}, isMe=${emptyStory.isMe}");
      }

      // 4. (Optional) Sort the processed stories for home screen display (e.g., current user first)
      if (_currentUser != null) {
        processedStories.sort((a, b) {
          if (a.userId == _currentUser!.id) return -1;
          if (b.userId == _currentUser!.id) return 1;
          return 0;
        });
      }

      print("🧾 Final processed stories: ${processedStories.map((s) => '${s.username}: hasStory=${s.hasStory}, isMe=${s.isMe}').toList()}");
      // 5. Assign the list of aggregated StoryData objects to _stories for home screen display
      _stories = processedStories;

      // Debug check
      if (_currentUser != null) {
        final currentUserFinalStory = _stories.firstWhere(
                (story) => story.userId == _currentUser?.id,
            orElse: () => StoryData(id: '', userId: '', username: 'N/A', profileImageUrl: '', mediaUrl: '', isMe: false, hasStory: false, isViewed: true, createdAt: DateTime.now())
        );
        print('InstaDataProvider - FINAL Current User Aggregated Story isViewed: ${currentUserFinalStory.isViewed}');
      }

      notifyListeners();
      print('InstaDataProvider: Stories fetched and aggregated successfully.');
    } catch (e) {
      _error = 'Failed to fetch stories: $e';
      print('Error fetching stories: $e');
      notifyListeners();
    }
  }
  // --- END OF MODIFIED _fetchStories() METHOD ---

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
}
