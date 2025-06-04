// Enhanced ReelProvider with follow, comment, and share logic
import 'dart:async';

import 'package:Instagram/screens/reels_screen/reel_modal.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/service/auth_service.dart';

class ReelProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Reel> reels = [];
  bool isLoading = false;
  Set<String> followingUsers = {}; // Track followed users

  String? _currentUserId;

  late final StreamSubscription<AuthState> _authStateSubscription; // New subscription to listen for auth changes

  ReelProvider() {
    _initializeUserAndAuthListener(); // New method to set up user and auth listener
  }

  void _initializeUserAndAuthListener() {
    // Initial user ID retrieval
    _updateCurrentUserId();
    _loadFollowingUsers();
    fetchReels(); // Fetch reels initially for the current user

    // Listen for auth state changes
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      // You can access data.session if needed, but for user ID, _updateCurrentUserId is enough.

      print('Auth state changed: $event'); // Great for debugging!

      // When the user signs in, signs out, or their user info is updated, refresh everything!
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userUpdated) {
        _updateCurrentUserId(); // Update the user ID in the provider
        _loadFollowingUsers(); // Reload following users for the new user
        fetchReels(); // Re-fetch reels to update like/follow status for the new user
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

  @override // Good practice to override dispose if you implement it
  void dispose() {
    _authStateSubscription.cancel(); // Crucial: Cancel the stream subscription to prevent memory leaks!
    super.dispose();
  }

  void _getCurrentUserId() {
    try {
      _currentUserId = AuthService.client().auth.currentUser?.id;
      if (_currentUserId != null) {
        print('Current user ID: $_currentUserId');
      } else {
        print('No authenticated user found');
      }
    } catch (e) {
      print('Error getting current user ID: $e');
      _currentUserId = null;
    }
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

  // Enhanced fetchReels with follow status
  Future<void> fetchReels() async {
    isLoading = true;
    notifyListeners();

    try {
      // First load following users to ensure we have current follow status
      await _loadFollowingUsers();

      final response = await supabase
          .from('reels')
          .select('''
            *,
            users!reels_user_id_fkey(username, profile_image_url),
            reel_likes(user_id)
          ''')
          .order('created_at', ascending: false);

      reels = (response as List).map((map) {
        final userId = map['user_id'] as String;
        final username = (map['users'] as Map?)?['username'] as String? ?? 'Unknown';
        final userAvatar = (map['users'] as Map?)?['profile_image_url'] as String? ?? '';
        final likes = map['likes'] as int? ?? 0;
        final commentCount = map['comment_count'] as int? ?? 0;

        // FIXED: Proper like status check
        final List<dynamic> reelLikes = map['reel_likes'] as List<dynamic>? ?? [];
        final bool isLikedByUser = _currentUserId != null &&
            reelLikes.any((likeMap) => (likeMap as Map<String, dynamic>)['user_id'] == _currentUserId);

        return Reel(
          id: map['id'],
          videoUrl: map['video_url'],
          userId: userId,
          username: username,
          userAvatar: _getPublicImageUrl(userAvatar, 'avatars'),
          caption: map['caption'],
          likes: likes,
          commentCount: commentCount,
          isLiked: isLikedByUser,
          isFollowing: followingUsers.contains(userId) && userId != _currentUserId, // FIXED: Don't show follow for own reels
          createdAt: DateTime.parse(map['created_at']),
          musicUrl: map['music_url'],
          musicTrimStart: map['music_trim_start']?.toDouble(),
          musicTrimEnd: map['music_trim_end']?.toDouble(),
          isVideoMuted: map['is_video_muted'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('Error fetching reels: $e');
    } finally {
      isLoading = false;
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
    final bool newIsLiked = !currentReel.isLiked;
    final int newLikesCount = newIsLiked ? currentReel.likes + 1 : currentReel.likes - 1;

    print('Toggling like for reel: $reelId, user: $_currentUserId, newIsLiked: $newIsLiked');

    // Optimistic update
    reels[index] = currentReel.copyWith(
        isLiked: newIsLiked,
        likes: newLikesCount
    );
    notifyListeners();

    try {
      if (newIsLiked) {
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

      print('Successfully ${newIsLiked ? 'liked' : 'unliked'} reel: $reelId');
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

      throw Exception('Failed to ${newIsLiked ? 'like' : 'unlike'} reel: ${e.toString()}');
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

  // Share reel functionality
  Future<void> shareReel(String reelId, String username, String caption) async {
    try {
      final reel = reels.firstWhere((r) => r.id == reelId);
      final shareText = '''Check out this amazing reel by @$username on Instagram!
      "$caption"
      ${reel.videoUrl}
      '''.trim();

      await Share.share(
        shareText,
        subject: 'Check out this reel by @$username',
      );

      print('Shared reel: $reelId');
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

      // FIXED: Update comment count atomically using RPC function
      await supabase.rpc('increment_comment_count', params: {'reel_id': reelId});

      // Update local state
      final reelIndex = reels.indexWhere((r) => r.id == reelId);
      if (reelIndex != -1) {
        final currentReel = reels[reelIndex];
        reels[reelIndex] = currentReel.copyWith(
            commentCount: currentReel.commentCount + 1
        );
        notifyListeners();
      }

      print('Successfully added comment to reel: $reelId');
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Failed to add comment. Please try again.');
    }
  }

  // Get comments for a reel
  Future<List<Map<String, dynamic>>> getReelComments(String reelId, {int limit = 50, int offset = 0}) async {
    try {
      final response = await supabase
          .from('comments')
          .select('''
            *,
            users!comments_user_id_fkey(username, profile_image_url)
          ''')
          .eq('reel_id', reelId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((comment) {
        final userData = comment['users'] as Map<String, dynamic>?;

        return {
          'id': comment['id'],
          'comment': comment['content'] ?? '',
          'username': userData?['username'] ?? 'Unknown User',
          'userAvatar': _getPublicImageUrl(
              userData?['profile_image_url'] as String?,
              'avatars'
          ),
          'createdAt': DateTime.parse(comment['created_at']),
          'userId': comment['user_id'], // FIXED: Add user ID for better handling
          'likes': comment['likes'] ?? 0, // FIXED: Add likes count if available
        };
      }).toList();
    } catch (e) {
      print('Error fetching comments: $e');
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
}