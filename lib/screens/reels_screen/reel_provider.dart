// Enhanced ReelProvider with follow, comment, and share logic
import 'dart:async';

import 'package:Instagram/screens/reels_screen/reel_modal.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../services/auth_service.dart';
import '../../services/blocked_users_service.dart';

class ReelProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Reel> reels = [];
  bool isInitiallyLoading = false;

  bool _isLoadingMore = false;
  bool _hasMoreReels = true;
  int _currentPage = 0;
  final int _reelsPerPage = 5; // Fetch 5 reels at a time

  Set<String> followingUsers = {}; // Track followed users
  String? _currentUserId;
  List<Map<String, dynamic>> _currentComments = [];
  List<Map<String, dynamic>> get currentComments => _currentComments;

  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, Future<void>> _initFutures = {};

  late final StreamSubscription<AuthState> _authStateSubscription; // New subscription to listen for auth changes

  ReelProvider() {
    _initializeUserAndAuthListener(); // New method to set up user and auth listener
  }

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreReels => _hasMoreReels;

  // Update the auth state change handler:
  void _initializeUserAndAuthListener() {
    _updateCurrentUserId();
    _loadFollowingUsers();
    fetchReels();

    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userUpdated) {

        // SEQUENTIAL execution to avoid race conditions
        _updateCurrentUserId();
        await _loadFollowingUsers(); // Wait for this to complete
        await fetchReels(); // Then fetch reels with correct user context
      }
    });
  }

  // NEW CODE - Replace the above section with this:
  void _updateCurrentUserId() { // Renamed for clarity, indicates it updates the state
    try {
      _currentUserId = AuthService.client().auth.currentUser?.id;
      if (_currentUserId != null) {
        print('Current user ID: $_currentUserId');
      } else {
        print('No authenticated user found');
        // If no user is authenticated, clear the reels and following users data
        reels = [];
        followingUsers = {};
      }
      notifyListeners(); // Notify listeners as user ID changes could affect UI
    } catch (e) {
      print('Error getting current user ID: $e');
      _currentUserId = null;
      reels = []; // Clear data on error or if user ID is null
      followingUsers = {};
      notifyListeners();
    }
  }

  // Added an optional parameter to control notification.
  void clearAllControllers({bool notify = true}) {
    print("🗑️ Clearing all video controllers...");
    _videoControllers.forEach((_, controller) {
      controller.dispose();
    });
    _videoControllers.clear();
    _initFutures.clear();
    reels.clear();

    // Only notify listeners if requested. We don't want this during dispose.
    if (notify) {
      notifyListeners();
    }
  }

  @override // Good practice to override dispose if you implement it
  void dispose() {
    _authStateSubscription.cancel(); // Crucial: Cancel the stream subscription to prevent memory leaks!
    _videoControllers.forEach((_, controller) {
      controller.dispose();
    });
    _videoControllers.clear();
    clearAllControllers(notify: false);
    super.dispose();
  }

  // --- NEW: Method to get or create a controller ---
  VideoPlayerController? getControllerForReel(String reelId) {
    return _videoControllers[reelId];
  }

  // --- NEW: Preloading Logic ---
  Future<void> preloadController(String reelId) async {
    // If controller already exists or is being initialized, return
    if (_videoControllers.containsKey(reelId) || _initFutures.containsKey(reelId)) {
      return;
    }

    try {
      final reel = reels.firstWhere(
              (r) => r.id == reelId,
          orElse: () => throw Exception("Reel not found for preloading")
      );

      final controller = VideoPlayerController.networkUrl(Uri.parse(reel.videoUrl));

      // Store the initialization future
      final initFuture = controller.initialize().timeout(
        Duration(seconds: 10), // Add timeout
        onTimeout: () {
          controller.dispose();
          throw Exception('Video initialization timeout');
        },
      ).then((_) {
        if (controller.value.isInitialized) {
          _videoControllers[reelId] = controller;
          print("✅ Successfully preloaded reel: $reelId");
        }
      }).catchError((error) {
        print("❌ Error preloading reel $reelId: $error");
        controller.dispose();
      }).whenComplete(() {
        _initFutures.remove(reelId);
      });

      _initFutures[reelId] = initFuture;

      // For the first reel, wait for initialization to complete
      if (reels.isNotEmpty && reels[0].id == reelId) {
        await initFuture;
      }

    } catch (e) {
      print("❌ Exception in preloadController for $reelId: $e");
      _initFutures.remove(reelId);
    }
  }

  // Add this new method to your ReelProvider class
  bool isControllerReady(String reelId) {
    final controller = _videoControllers[reelId];
    return controller != null && controller.value.isInitialized;
  }

  // --- NEW: Method to handle preloading adjacent reels ---
  void preloadAdjacentReels(int currentIndex) {
    if (currentIndex < 0 || currentIndex >= reels.length) return;

    // --- NEW: Check if we need to fetch the next page ---
    if (_hasMoreReels && !_isLoadingMore && currentIndex >= reels.length - 2) {
      print('Preloading triggered fetch for more reels...');
      _loadMoreReels();
    }

    // Preload the next reel if it exists
    if (currentIndex + 1 < reels.length) {
      preloadController(reels[currentIndex + 1].id);
    }

    // Preload the previous reel
    if (currentIndex - 1 >= 0) {
      preloadController(reels[currentIndex - 1].id);
    }

    // --- Optional: Advanced Cleanup Logic ---
    // Dispose controllers that are too far away to save memory
    final activeReelIds = {
      if (currentIndex < reels.length) reels[currentIndex].id,
      if (currentIndex + 1 < reels.length) reels[currentIndex + 1].id,
      if (currentIndex - 1 >= 0) reels[currentIndex - 1].id,
    };

    _videoControllers.keys.toList().forEach((reelId) {
      if (!activeReelIds.contains(reelId)) {
        _videoControllers[reelId]?.dispose();
        _videoControllers.remove(reelId);
        print("🗑️ Disposed of off-screen reel controller: $reelId");
      }
    });
  }

  // Load users that current user is following
  Future<void> _loadFollowingUsers() async {
    if (_currentUserId == null) return;

    try {
      final response = await supabase
          .from('followers')
          .select('following_id')
          .eq('follower_id', _currentUserId!);

      followingUsers = (response as List)
          .map((item) => item['following_id'] as String)
          .toSet();

      print('Loaded ${followingUsers.length} following users');
    } catch (e) {
      print('Error loading following users: $e');
      followingUsers = <String>{}; // Initialize empty set on error
    }
  }

  // THIS METHOD IS REFACTORED for initial loading and reset
  Future<void> fetchReels() async {
    // This now acts as a reset and initial fetch function
    isInitiallyLoading = true;
    _currentPage = 0;
    _hasMoreReels = true;
    reels.clear();
    _videoControllers.forEach((_, controller) => controller.dispose());
    _videoControllers.clear();
    _initFutures.clear();

    await _loadMoreReels(); // Fetch the first page
    isInitiallyLoading = false;
    notifyListeners();
  }

  // --- NEW METHOD: Fetches the next page of reels ---
  Future<void> _loadMoreReels() async {
    if (_isLoadingMore || !_hasMoreReels) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _updateCurrentUserId();
      await _loadFollowingUsers();

      final blockedService = BlockedUsersService();
      final blockedUsers = await blockedService.getBlockedUsers();
      final blockedIds = blockedUsers.map((u) => u['id']).toSet();

      final from = _currentPage * _reelsPerPage;
      final to = from + _reelsPerPage - 1;

      // The rest of the fetching logic is the same, but with .range() added
      final response = await supabase
          .from('reels')
          .select('''
        *,
        users!reels_user_id_fkey(username, profile_image_url),
        comments(id)
      ''')
          .order('created_at', ascending: false)
          .range(from, to); // <-- PAGINATION APPLIED HERE

      final List<dynamic> reelDataList = response as List<dynamic>;

      if (reelDataList.length < _reelsPerPage) {
        _hasMoreReels = false;
      }

      // Second query to get likes remains efficient
      final reelIds = reelDataList.map((data) => data['id']).toList();
      if (reelIds.isEmpty) {
        _isLoadingMore = false;
        notifyListeners();
        return;
      }

      final likesResponse = await supabase
          .from('reel_likes')
          .select('reel_id')
          .eq('user_id', _currentUserId as Object)
          .inFilter('reel_id', reelIds);

      final likedReelIds = (likesResponse as List<dynamic>)
          .map((like) => like['reel_id'])
          .toSet();

      final newReels = reelDataList
          .where((data) => !blockedIds.contains(data['user_id']))
          .map((data) {
        // ... (mapping logic remains exactly the same)
        final reelId = data['id'] as String;
        final userId = data['user_id'] as String;
        final user = data['users'] as Map<String, dynamic>? ?? {};
        final username = user['username'] ?? 'Unknown';
        final avatarPath = user['profile_image_url'] ?? '';
        final comments = data['comments'] as List<dynamic>? ?? [];
        final likesCount = data['likes'] as int? ?? 0;
        final bool isLiked = likedReelIds.contains(reelId);

        return Reel(
          id: reelId,
          videoUrl: data['video_url'],
          userId: userId,
          username: username,
          userAvatar: _getPublicImageUrl(avatarPath, 'avatars'),
          caption: data['caption'] ?? '',
          likes: likesCount,
          commentCount: comments.length,
          isLiked: isLiked,
          isFollowing: followingUsers.contains(userId) && userId != _currentUserId,
          createdAt: DateTime.parse(data['created_at']),
          musicUrl: data['music_url'],
          musicTrimStart: (data['music_trim_start'] as num?)?.toDouble(),
          musicTrimEnd: (data['music_trim_end'] as num?)?.toDouble(),
          isVideoMuted: data['is_video_muted'] ?? false,
        );
      }).toList();

      reels.addAll(newReels);
      _currentPage++;

      // Preload the first one or two reels from the newly fetched page
      if (newReels.isNotEmpty) {
        await preloadController(newReels[0].id);
        if (newReels.length > 1) {
          preloadController(newReels[1].id);
        }
      }
    } catch (e, st) {
      print('❌ Error fetching more reels: $e');
      print(st);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  String _getPublicImageUrl(String? path, String bucketName) {
    if (path == null || path.isEmpty || path.startsWith('http')) {
      return path ?? '';
    }
    return supabase.storage.from(bucketName).getPublicUrl(path);
  }

  // Enhanced like toggle with haptic feedback
  Future<void> toggleReelLike(String reelId) async {
    if (_currentUserId == null) {
      print('Error: No current user ID');
      return;
    }

    final index = reels.indexWhere((reel) => reel.id == reelId);
    if (index == -1) {
      print('Error: Reel not found with ID: $reelId');
      return;
    }

    final currentReel = reels[index];
    final bool newReelIsLiked = !currentReel.isLiked;
    final int newLikesCount = newReelIsLiked ? currentReel.likes + 1 : currentReel.likes - 1;

    print('Toggling like for reel: $reelId, user: $_currentUserId, newIsLiked: $newReelIsLiked');

    // Optimistic update
    reels[index] = currentReel.copyWith(
        isLiked: newReelIsLiked,
        likes: newLikesCount
    );
    notifyListeners();

    try {
      if (newReelIsLiked) {
        print('Attempting to insert like...');
        final response = await supabase.from('reel_likes').upsert({
          'reel_id': reelId,
          'user_id': _currentUserId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'reel_id,user_id');
        print('Like upsert response: $response');
      } else {
        print('Attempting to delete like...');
        final response = await supabase
            .from('reel_likes')
            .delete()
            .eq('reel_id', reelId)
            .eq('user_id', _currentUserId!);
        print('Like delete response: $response');
      }

      print('Updating likes count in reels table...');
      final updateResponse = await supabase
          .from('reels')
          .update({'likes': newLikesCount})
          .eq('id', reelId);
      print('Reels update response: $updateResponse');

      print('Successfully ${newReelIsLiked ? 'liked' : 'unliked'} reel: $reelId');
    } catch (e) {
      print('Detailed error: $e');
      print('Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('Postgrest error code: ${e.code}');
        print('Postgrest error message: ${e.message}');
        print('Postgrest error details: ${e.details}');
      }

      // Revert optimistic update
      reels[index] = currentReel;
      notifyListeners();

      throw Exception('Failed to ${newReelIsLiked ? 'like' : 'unlike'} reel: ${e.toString()}');
    }
  }


  // Follow/Unfollow user
  Future<void> toggleUserFollow(String userId, String username) async {
    if (_currentUserId == null || userId == _currentUserId) return;

    final bool isCurrentlyFollowing = followingUsers.contains(userId);
    final bool newFollowStatus = !isCurrentlyFollowing;

    // Optimistic update
    if (newFollowStatus) {
      followingUsers.add(userId);
    } else {
      followingUsers.remove(userId);
    }

    // Update reels list
    for (int i = 0; i < reels.length; i++) {
      if (reels[i].userId == userId) {
        reels[i] = reels[i].copyWith(isFollowing: newFollowStatus);
      }
    }
    notifyListeners();

    try {
      if (newFollowStatus) {
        // FIXED: Use upsert to prevent duplicate follow entries
        await supabase.from('followers').upsert({
          'follower_id': _currentUserId,
          'following_id': userId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'follower_id,following_id');
      } else {
        await supabase
            .from('followers')
            .delete()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', userId);
      }

      print('Successfully ${newFollowStatus ? 'followed' : 'unfollowed'} user: $username');
    } catch (e) {
      print('Error toggling follow: $e');

      // Revert optimistic update
      if (!newFollowStatus) {
        followingUsers.add(userId);
      } else {
        followingUsers.remove(userId);
      }

      for (int i = 0; i < reels.length; i++) {
        if (reels[i].userId == userId) {
          reels[i] = reels[i].copyWith(isFollowing: !newFollowStatus);
        }
      }
      notifyListeners();

      throw Exception('Failed to ${newFollowStatus ? 'follow' : 'unfollow'} user. Please try again.');
    }
  }

  // In reel_provider.dart
  Future<void> shareReel(String reelId, String username, String caption) async {
    try {
      // 1. IMPORTANT: Replace with your actual Netlify URL
      const webAppBaseUrl = 'https://reelswebfallback.netlify.app'; // <-- Use your Netlify URL

      // 2. Add the "/reel" path to match your AndroidManifest.xml
      final reelUrl = '$webAppBaseUrl/reel?id=$reelId';

      final shareText = '''Check out this amazing reel by @$username!

$reelUrl
    '''.trim();

      await Share.share(
        shareText,
        subject: 'Check out this reel by @$username',
      );

      print('Shared reel: $reelId with URL: $reelUrl');
    } catch (e) {
      print('Error sharing reel: $e');
    }
  }

  // Add comment to reel
  // FIXED: Enhanced add comment with proper validation and error handling
  Future<void> addComment(String reelId, String comment) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) throw Exception('Comment cannot be empty');

    if (trimmedComment.length > 500) throw Exception('Comment is too long');

    try {
      // Insert comment
      final response = await supabase.from('comments').insert({
        'reel_id': reelId,
        'user_id': _currentUserId,
        'content': trimmedComment,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).select().single();

      // Use only RPC function for consistency
      await supabase.rpc('increment_comment_count', params: {'reel_id': reelId});

      await getReelCommentsWithLikes(reelId);
      // REFRESH the specific reel data instead of optimistic update
      await _refreshSingleReel(reelId);
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Failed to add comment. Please try again.');
    }
  }

  Future<void> _refreshSingleReel(String reelId) async {
    try {
      // Get reel data with likes
      final reelResponse = await supabase
          .from('reels')
          .select('likes, reel_likes(user_id)')
          .eq('id', reelId)
          .single();

      // Get actual comment count from comments table
      final commentResponse = await supabase
          .from('comments')
          .select('id')
          .eq('reel_id', reelId);

      final reelIndex = reels.indexWhere((r) => r.id == reelId);
      if (reelIndex != -1) {
        final currentReel = reels[reelIndex];
        final likes = reelResponse['reel_likes'] as List? ?? [];
        final isLiked = _currentUserId != null &&
            likes.any((like) => like['user_id'] == _currentUserId);

        print('Current reel: $currentReel');
        print('Comment Count: ${commentResponse.length}');

        reels[reelIndex] = currentReel.copyWith(
          commentCount: commentResponse.length, // Use actual count from comments table
          likes: reelResponse['likes'] ?? 0,
          isLiked: isLiked,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing single reel: $e');
    }
  }

  // Add this method to your ReelProvider class

// Toggle comment like with optimistic updates
  Future<void> toggleCommentLike(String commentId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final commentIndex = _currentComments.indexWhere((c) => c['id'] == commentId);
    if (commentIndex == -1) return; // Comment not in the current list

    final comment = _currentComments[commentIndex];
    final bool originalLikeState = comment['is_liked'] ?? false;
    final int originalLikeCount = comment['likes'] ?? 0;

    // 1. Optimistic Update: Instantly update the UI
    comment['is_liked'] = !originalLikeState;
    comment['likes'] = originalLikeState ? originalLikeCount - 1 : originalLikeCount + 1;
    notifyListeners();

    // 2. Database Operation
    try {
      if (!originalLikeState) { // New state is "liked"
        await supabase.from('comment_likes').upsert({
          'comment_id': commentId,
          'user_id': _currentUserId,
        });
      } else { // New state is "unliked"
        await supabase
            .from('comment_likes')
            .delete()
            .match({'comment_id': commentId, 'user_id': _currentUserId!});
      }
    } catch (e) {
      // 3. Revert on Error
      comment['is_liked'] = originalLikeState;
      comment['likes'] = originalLikeCount;
      notifyListeners();
      throw Exception('Failed to update like status.');
    }
  }

// Helper method to get comment like status and count
  Future<Map<String, dynamic>> getCommentLikeInfo(String commentId) async {
    try {
      // Get total likes count
      final likesResponse = await supabase
          .from('comment_likes')
          .select('id, user_id')
          .eq('comment_id', commentId);

      final likes = likesResponse as List;
      final likesCount = likes.length;

      // Check if current user liked this comment
      final isLiked = _currentUserId != null &&
          likes.any((like) => like['user_id'] == _currentUserId);

      return {
        'likesCount': likesCount,
        'isLiked': isLiked,
      };
    } catch (e) {
      print('Error getting comment like info: $e');
      return {
        'likesCount': 0,
        'isLiked': false,
      };
    }
  }

  /// Fetches comments for a reel and stores them in the provider's state.
  Future<void> getReelCommentsWithLikes(String reelId) async {
    try {
      final response = await supabase
          .from('comments')
          .select('''
          *,
          users!comments_user_id_fkey(username, profile_image_url),
          comment_likes(user_id)
        ''')
          .eq('reel_id', reelId)
          .order('created_at', ascending: false);

      final commentsList = (response as List).map((comment) {
        final userData = comment['users'] as Map<String, dynamic>?;
        final likes = comment['comment_likes'] as List? ?? [];
        final isLiked = _currentUserId != null &&
            likes.any((like) => like['user_id'] == _currentUserId);

        return {
          'id': comment['id'],
          'comment': comment['content'] ?? '',
          'username': userData?['username'] ?? 'Unknown User',
          'userAvatar': _getPublicImageUrl(
              userData?['profile_image_url'] as String?, 'avatars'),
          'createdAt': DateTime.parse(comment['created_at']),
          'userId': comment['user_id'],
          'likes': likes.length, // Changed from likesCount
          'is_liked': isLiked, // Changed from isLiked
        };
      }).toList();

      _currentComments = commentsList;
      notifyListeners(); // Notify UI that comments are ready

    } catch (e) {
      print('Error fetching comments with likes: $e');
      throw Exception('Failed to load comments. Please try again.');
    }
  }

  // Check if user is following another user
  bool isFollowing(String userId) {
    return followingUsers.contains(userId);
  }

  Future<void> deleteCommentWithFeedback(String reelId, Map<String, dynamic> comment,
      {Function(String)? onError, Function()? onSuccess}) async {

    // Optimistic update
    final reelIndex = reels.indexWhere((r) => r.id == reelId);
    Reel? originalReel;

    if (reelIndex != -1) {
      originalReel = reels[reelIndex];
      reels[reelIndex] = originalReel.copyWith(
          commentCount: originalReel.commentCount - 1
      );
      notifyListeners();
    }

    try {
      // Delete the comment
      await supabase
          .from('comments')
          .delete()
          .eq('id', comment['id']);

      // Update comment count using RPC or direct update
      try {
        await supabase.rpc('decrement_comment_count', params: {'reel_id': reelId});
      } catch (rpcError) {
        // Fallback to direct update if RPC fails
        print('RPC failed, using direct update: $rpcError');
        await supabase
            .from('reels')
            .update({'comment_count': (originalReel?.commentCount ?? 1) - 1})
            .eq('id', reelId);
      }

      print('Successfully deleted comment from reel: $reelId');
      await getReelCommentsWithLikes(reelId);
      onSuccess?.call();

    } catch (e) {
      print('Error deleting comment: $e');

      // Revert optimistic update
      if (reelIndex != -1 && originalReel != null) {
        reels[reelIndex] = originalReel;
        notifyListeners();
      }

      onError?.call('Failed to delete comment. Please try again.');
    }
  }

  // Refactored updateReelMuteState method - Local audio control for viewer
  Future<void> updateReelMuteState(String reelId, bool isMuted) async {
    try {
      // Find the reel index
      final reelIndex = reels.indexWhere((reel) => reel.id == reelId);
      if (reelIndex == -1) {
        print('Reel not found with ID: $reelId');
        return;
      }

      // Update local state only (no database update needed)
      // This is for viewer's audio preference, not permanent reel property
      final originalReel = reels[reelIndex];
      reels[reelIndex] = originalReel.copyWith(isVideoMuted: isMuted);
      notifyListeners();

      print('Successfully ${isMuted ? 'muted' : 'unmuted'} reel audio locally: $reelId');

    } catch (e) {
      print('Error updating reel mute state: $e');
      throw Exception('Failed to update audio state: ${e.toString()}');
    }
  }

// Refactored deleteReel method
  Future<void> deleteReel(
      String reelId, {
        Function(String)? onError,
        Function()? onSuccess,
      }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Find the reel to delete
      final reelIndex = reels.indexWhere((reel) => reel.id == reelId);
      if (reelIndex == -1) {
        throw Exception('Reel not found');
      }

      final reelToDelete = reels[reelIndex];

      // Check if current user owns the reel
      if (reelToDelete.userId != _currentUserId) {
        throw Exception('You can only delete your own reels');
      }

      // Optimistic update
      final originalReels = List<Reel>.from(reels);
      reels.removeAt(reelIndex);
      notifyListeners();

      // Step 1: Delete associated notifications
      final notifResponse = await supabase
          .from('notifications')
          .delete()
          .eq('reel_id', reelId);

      print('🧾 Notifications delete response: $notifResponse');


      // Step 2: Delete associated comments and likes
      await Future.wait([
        supabase.from('comments').delete().eq('reel_id', reelId),
        supabase.from('reel_likes').delete().eq('reel_id', reelId),
      ]);

      // Step 3: Delete the reel itself
      final response = await supabase
          .from('reels')
          .delete()
          .eq('id', reelId);

      // Optional: Check for rows deleted
      if (response is List && response.isEmpty) {
        // Optionally throw or log
      }

      // Step 4: Delete video from storage (if applicable)
      if (reelToDelete.videoUrl.isNotEmpty &&
          !reelToDelete.videoUrl.startsWith('http')) {
        try {
          await supabase.storage
              .from('reels')
              .remove([reelToDelete.videoUrl]);
        } catch (storageError) {
          // Ignore storage deletion errors
        }
      }

      await fetchReels();
      onSuccess?.call();

    } catch (e) {
      // Revert optimistic update
      try {
        print('Reverting optimistic update by refreshing reels...');
        await fetchReels();
      } catch (fetchError) {
        print('Error refreshing reels after delete failure: $fetchError');
      }

      final errorMessage = 'Failed to delete reel: ${e.toString()}';
      onError?.call(errorMessage);
      throw Exception(errorMessage);
    }
  }
}