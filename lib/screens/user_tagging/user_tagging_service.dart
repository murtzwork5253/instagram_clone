// services/user_tagging_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_model.dart';

class UserTaggingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Search users for tagging
  Future<List<SearchableUser>> searchUsers({
    required String query,
    required String currentUserId,
    int limit = 20,
  }) async {
    try {
      if (query.trim().isEmpty) {
        // Return recent users or followers if no query
        return await _getRecentUsers(currentUserId, limit);
      }

      final response = await _supabase
          .from('users')
          .select('id, username, profile_image_url, full_name')
          .ilike('username', '%$query%')
          .neq('id', currentUserId)
          .limit(limit);

      return (response as List)
          .map((user) => SearchableUser.fromJson(user))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get recent users (followers/following)
  Future<List<SearchableUser>> _getRecentUsers(String currentUserId, int limit) async {
    try {
      final response = await _supabase
          .rpc('get_recent_users_for_tagging', params: {
        'user_id': currentUserId,
        'limit_count': limit,
      });

      return (response as List)
          .map((user) => SearchableUser.fromJson(user))
          .toList();
    } catch (e) {
      print('Error getting recent users: $e');
      // Fallback to all users
      final response = await _supabase
          .from('users')
          .select('id, username, profile_image_url, full_name')
          .neq('id', currentUserId)
          .limit(limit);

      return (response as List)
          .map((user) => SearchableUser.fromJson(user))
          .toList();
    }
  }

  // Get user details by ID
  Future<SearchableUser?> getUserById(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id, username, profile_image_url, full_name')
          .eq('id', userId)
          .single();

      return SearchableUser.fromJson(response);
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Save tagged users to post
  Future<bool> saveTaggedUsersToPost({
    required String postId,
    required List<TaggedUser> taggedUsers,
  }) async {
    try {
      final taggedUsersJson = taggedUsers.map((user) => user.toJson()).toList();

      await _supabase
          .from('posts')
          .update({'tagged_users': taggedUsersJson})
          .eq('id', postId);

      return true;
    } catch (e) {
      print('Error saving tagged users to post: $e');
      return false;
    }
  }

  Future<bool> saveTaggedUsersToReel(
      {required String reelId, required List<TaggedUser> taggedUsers}) async {
    try {
      final taggedUsersJson = taggedUsers.map((user) => user.toJson()).toList();
      await _supabase
          .from('reels')
          .update({'tagged_users': taggedUsersJson})
          .eq('id', reelId);
      return true;
      } catch (e) {
      print('Error saving tagged users to reel: $e');
      return false;
    }
  }

  // Get tagged users from post
  Future<List<TaggedUser>> getTaggedUsersFromPost(String postId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('tagged_users')
          .eq('id', postId)
          .single();

      final taggedUsersJson = response['tagged_users'] as List?;
      if (taggedUsersJson == null) return [];

      return taggedUsersJson
          .map((json) => TaggedUser.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting tagged users from post: $e');
      return [];
    }
  }

  Future<List<TaggedUser>> getTaggedUsersFromReel(String reelId) async {
    try {
      final response = await _supabase
          .from('reels')
          .select('tagged_users')
          .eq('id', reelId)
          .single();
      final taggedUsersJson = response['tagged_users'] as List?;
      if (taggedUsersJson == null) return [];
      return taggedUsersJson
          .map((json) => TaggedUser.fromJson(json as Map<String, dynamic>))
          .toList();
      } catch (e) {
      print('Error getting tagged users from reel: $e');
      return [];
    }
  }

  // Notify tagged users (optional)
  // Future<void> notifyTaggedUsers({
  //   required List<TaggedUser> taggedUsers,
  //   required String postId,
  //   required String authorId,
  // }) async {
  //   try {
  //     // Create notifications for tagged users
  //     final notifications = taggedUsers.map((user) => {
  //       'user_id': user.id,
  //       'type': 'tag',
  //       'title': 'You were tagged in a post',
  //       'body': 'Someone tagged you in their post',
  //       'data': {
  //         'post_id': postId,
  //         'author_id': authorId,
  //       },
  //       'created_at': DateTime.now().toIso8601String(),
  //     }).toList();
  //
  //     if (notifications.isNotEmpty) {
  //       await _supabase.from('notifications').insert(notifications);
  //     }
  //   } catch (e) {
  //     print('Error notifying tagged users: $e');
  //   }
  // }

  Future<bool> saveTaggedUsersToStory({
    required String storyId,
    required List<TaggedUser> taggedUsers,
  }) async {
    try {
      final taggedUsersJson = taggedUsers.map((user) => user.toJson()).toList();

      await _supabase
          .from('stories')
          .update({'tagged_users': taggedUsersJson})
          .eq('id', storyId);

      return true;
    } catch (e) {
      print('Error saving tagged users to story: $e');
      return false;
    }
  }

  Future<List<TaggedUser>> getTaggedUsersFromStory(String storyId) async {
    try {
      final response = await _supabase
          .from('stories')
          .select('tagged_users')
          .eq('id', storyId)
          .single();

      final taggedUsersJson = response['tagged_users'] as List?;
      if (taggedUsersJson == null) return [];

      return taggedUsersJson
          .map((json) => TaggedUser.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting tagged users from story: $e');
      return [];
    }
  }
}