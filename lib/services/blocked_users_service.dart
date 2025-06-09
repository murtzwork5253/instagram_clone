import 'package:supabase_flutter/supabase_flutter.dart';

class BlockedUsersService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Block a user
  Future<void> blockUser(String blockedUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not logged in');

    await _supabase.from('blocked_users').insert({
      'blocker_id': currentUserId,
      'blocked_id': blockedUserId,
    });
  }

  // Unblock a user
  Future<void> unblockUser(String blockedUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not logged in');

    await _supabase.from('blocked_users')
        .delete()
        .eq('blocker_id', currentUserId)
        .eq('blocked_id', blockedUserId);
  }

  // Get list of blocked users
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not logged in');

    final response = await _supabase
        .from('blocked_users')
        .select('''
          blocked_id,
          users!blocked_users_blocked_id_fkey (
            id,
            username,
            profile_image_url
          )
        ''')
        .eq('blocker_id', currentUserId);

    return response.map((block) {
      final user = block['users'] as Map<String, dynamic>;
      return {
        'id': user['id'],
        'username': user['username'],
        'profileImageUrl': user['profile_image_url'],
      };
    }).toList();
  }

  // Check if a user is blocked
  Future<bool> isUserBlocked(String userId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not logged in');

    final response = await _supabase
        .from('blocked_users')
        .select()
        .eq('blocker_id', currentUserId)
        .eq('blocked_id', userId)
        .maybeSingle();

    return response != null;
  }
} 