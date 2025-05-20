import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';

class InstaDataProvider extends ChangeNotifier {
  bool _isLoading = false;
  UserData? _currentUser;
  List<PostData> _posts = [];
  List<StoryData> _stories = [];
  String? _error;

  bool get isLoading => _isLoading;

  UserData? get currentUser => _currentUser;

  List<PostData> get posts => _posts;

  List<StoryData> get stories => _stories;

  String? get error => _error;

  InstaDataProvider() {
    _initData();
  }

  Future<void> _initData() async {
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
      print('Fetching posts...');
      final fetchedPosts = await SupabaseService.getFeedPosts();
      print('Posts fetched: ${fetchedPosts.length}');
      _posts = fetchedPosts;
      notifyListeners();
    } catch (e) {
      print('Error fetching posts: $e');
      _error = 'Failed to load posts';
    }
  }

  Future<void> _fetchStories() async {
    try {
      print('Fetching stories...');
      final fetchedStories = await SupabaseService.getStories();
      print('Stories fetched: ${fetchedStories.length}');
      _stories = fetchedStories;
      notifyListeners();
    } catch (e) {
      print('Error fetching stories: $e');
      // Don't set error for stories as it's not critical
    }
  }

  Future<void> refreshFeed() async {
    setLoading(true);
    _error = null;

    try {
      await Future.wait([
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
      Fluttertoast.showToast(msg: "Error toggling like");
      // Refresh feed to get correct state
      refreshFeed();
    }
  }

  Future<void> addComment(String postId, String content) async {
    try {
      await SupabaseService.addComment(postId, content);

      // Update comment count
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
    } catch (e) {
      Fluttertoast.showToast(msg: "Error Adding Comment");
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

  Future<void> createStory(String mediaUrl) async {
    try {
      await SupabaseService.createStory(mediaUrl);

      // Refresh stories to show the new one
      _fetchStories();

      Fluttertoast.showToast(msg: "Story Created Successfully");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error Creating Story");
    }
  }

  Future<void> viewStory(String storyId) async {
    try {
      await SupabaseService.markStoryAsViewed(storyId);

      // Update the viewed status locally
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
          isViewed: true,
        );
        _stories = newStories;
        notifyListeners();
      }
    } catch (e) {
      // Silent failure for story views
      print('Error marking story as viewed: ${e.toString()}');
    }
  }
}
