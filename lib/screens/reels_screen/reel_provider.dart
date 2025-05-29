import 'package:Instagram/screens/reels_screen/reel_modal.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/service/auth_service.dart';

class ReelProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Reel> reels = [];
  bool isLoading = false;

  String? _currentUserId; // To store current user ID

  ReelProvider() {
    _getCurrentUserId(); // Fetch user ID on initialization
  }

  void _getCurrentUserId() {
    _currentUserId = AuthService.client().auth.currentUser?.id;
  }

  Future<void> fetchReels() async {
    isLoading = true;
    notifyListeners();
    try {
      final response = await supabase
          .from('reels')
          .select('''
            *,
            users!reels_user_id_fkey(username, profile_image_url),
            reel_likes(user_id) // Fetch likes for current user if applicable
          ''') // Updated to fetch user info and likes
          .order('created_at', ascending: false);

      reels = (response as List).map((map) {
        final userId = map['user_id'] as String;
        final username = (map['users'] as Map?)?['username'] as String? ?? 'Unknown';
        final userAvatar = (map['users'] as Map?)?['profile_image_url'] as String? ?? '';
        final likes = map['likes'] as int? ?? 0; // Assuming 'likes' column in reels table
        final commentCount = map['comment_count'] as int? ?? 0; // Assuming 'comment_count' column

        // Determine if current user liked this reel
        final List<dynamic> reelLikes = map['reel_likes'] as List<dynamic>? ?? [];
        final bool isLikedByUser = _currentUserId != null &&
            reelLikes.any((likeMap) => (likeMap as Map<String, dynamic>)['user_id'] == _currentUserId);

        return Reel(
          id: map['id'],
          videoUrl: map['video_url'],
          userId: userId,
          username: username,
          userAvatar: _getPublicImageUrl(userAvatar, 'avatars'), // Use helper for avatar URL
          caption: map['caption'],
          likes: likes,
          commentCount: commentCount,
          isLiked: isLikedByUser,
          createdAt: DateTime.parse(map['created_at']),
        );
      }).toList();
    } catch (e) {
      print('Error fetching reels: $e');
      // Handle error, e.g., show a toast
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Helper to get public URL for avatars or reel videos
  String _getPublicImageUrl(String? path, String bucketName) {
    if (path == null || path.isEmpty || path.startsWith('http')) {
      return path ?? ''; // Return empty string or already public URL
    }
    return supabase.storage.from(bucketName).getPublicUrl(path);
  }

  // New method to toggle reel like status
  Future<void> toggleReelLike(String reelId) async {
    if (_currentUserId == null) {
      // Handle case where user is not logged in (e.g., show login prompt)
      return;
    }

    final index = reels.indexWhere((reel) => reel.id == reelId);
    if (index == -1) return;

    final currentReel = reels[index];
    final bool newIsLiked = !currentReel.isLiked;
    final int newLikesCount = newIsLiked ? currentReel.likes + 1 : currentReel.likes - 1;

    // Optimistic update
    reels[index] = currentReel.copyWith(isLiked: newIsLiked, likes: newLikesCount);
    notifyListeners();

    try {
      if (newIsLiked) {
        await supabase.from('reel_likes').insert({
          'reel_id': reelId,
          'user_id': _currentUserId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await supabase
            .from('reel_likes')
            .delete()
            .eq('reel_id', reelId)
            .eq('user_id', _currentUserId!);
      }
      // No need to reconcile if API call succeeds and optimistic update is accurate
    } catch (e) {
      print('Error toggling reel like: $e');
      // Revert optimistic update on error
      reels[index] = currentReel.copyWith(isLiked: currentReel.isLiked, likes: currentReel.likes);
      notifyListeners();
      // Show error toast
    }
  }


  // You might also need a method to fetch a single reel if you navigate to it
  // and it's not in the current 'reels' list.
  Future<Reel?> fetchSingleReel(String reelId) async {
    try {
      final response = await supabase
          .from('reels')
          .select('''
            *,
            users!reels_user_id_fkey(username, profile_image_url),
            reel_likes(user_id)
          ''')
          .eq('id', reelId)
          .single();

      final userId = response['user_id'] as String;
      final username = (response['users'] as Map?)?['username'] as String? ?? 'Unknown';
      final userAvatar = (response['users'] as Map?)?['profile_image_url'] as String? ?? '';
      final likes = response['likes'] as int? ?? 0;
      final commentCount = response['comment_count'] as int? ?? 0;

      final List<dynamic> reelLikes = response['reel_likes'] as List<dynamic>? ?? [];
      final bool isLikedByUser = _currentUserId != null &&
          reelLikes.any((likeMap) => (likeMap as Map<String, dynamic>)['user_id'] == _currentUserId);

      return Reel(
        id: response['id'],
        videoUrl: response['video_url'],
        userId: userId,
        username: username,
        userAvatar: _getPublicImageUrl(userAvatar, 'avatars'),
        caption: response['caption'],
        likes: likes,
        commentCount: commentCount,
        isLiked: isLikedByUser,
        createdAt: DateTime.parse(response['created_at']),
      );
    } catch (e) {
      print('Error fetching single reel: $e');
      return null;
    }
  }
}