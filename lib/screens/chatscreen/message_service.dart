import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/chatscreen/model/models.dart' as models;

// --- Message Service for Supabase Interactions ---
class MessageService {
  final SupabaseClient _supabaseClient = Supabase.instance.client; // Use your existing Supabase client

  // Search users method - you can replace this with your existing method
  Future<List<models.User>> searchUsers(String query, String currentUserId) async {
    try {
      // Fetch blocked users
      final blocked = await _supabaseClient
        .from('blocked_users')
        .select('blocked_id')
        .eq('blocker_id', currentUserId);
      final blockedIds = blocked.map((b) => b['blocked_id'] as String).toSet();

      var queryBuilder = _supabaseClient
          .from('users')
          .select('id, username, profile_image_url, email')
          .neq('id', currentUserId); // Exclude current user

      if (query.trim().isNotEmpty) {
        queryBuilder = queryBuilder.ilike('username', '%$query%');
      }

      final response = await queryBuilder.limit(20);

      // Filter out blocked users
      final filtered = response.where((json) => !blockedIds.contains(json['id'])).toList();
      return filtered.map((json) => models.User.fromJson(json)).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Stream<List<models.Message>> getMessagesWithFunction({required String currentUserId, required String otherUserId}) {
    return _supabaseClient
        .rpc('get_messages_between_users', params: {
      'user1_id': currentUserId,
      'user2_id': otherUserId,
    })
        .asStream()
        .map((data) => (data as List).map((json) => models.Message.fromJson(json)).toList());
  }

  // Send a new message
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    String? content,
    String? imageUrl,
  }) async {
    if (content == null && imageUrl == null) {
      throw ArgumentError('Message must have content or an image.');
    }

    await _supabaseClient.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'image_url': imageUrl,
      'is_read': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int> getUnreadMessageCount(String currentUserId, String otherUserId) async {
    try {
      final response = await _supabaseClient
          .from('messages')
          .select('id')
          .eq('receiver_id', currentUserId)
          .eq('sender_id', otherUserId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  models.ChatStatus calculateChatStatus({
    required models.Message? lastMessage,
    required String currentUserId,
    required int unreadCount,
  }) {
    if (lastMessage == null) {
      return models.ChatStatus.normal(null);
    }

    // Check for unread messages from other user
    if (unreadCount > 0) {
      return models.ChatStatus.unreadMessages(unreadCount);
    }

    // Current user sent last message
    if (lastMessage.senderId == currentUserId) {
      if (lastMessage.isRead && lastMessage.seenAt != null) {
        return models.ChatStatus.seen(lastMessage.seenAt!);
      } else {
        return models.ChatStatus.sent(lastMessage.createdAt);
      }
    }

    // Other user sent last message and current user has read it
    return models.ChatStatus.normal(lastMessage.content ?? (lastMessage.imageUrl != null ? 'Sent a photo' : ''));
  }

  // Enhanced method to mark messages as read with better handling
  Future<void> markMessagesAsRead({
    required String currentUserId,
    required String otherUserId
  }) async {
    try {
      await _supabaseClient
          .from('messages')
          .update({
        'is_read': true,
        'seen_at': DateTime.now().toUtc().toIso8601String(),
      })
          .eq('sender_id', otherUserId)
          .eq('receiver_id', currentUserId)
          .eq('is_read', false); // Only update unread messages

      print('Messages marked as read for user: $otherUserId');
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Add method to get messages stream with proper handling
  Stream<List<models.Message>> getMessagesStream({
    required String currentUserId,
    required String otherUserId
  }) {
    return _supabaseClient
        .rpc('get_messages_between_users', params: {
      'user1_id': currentUserId,
      'user2_id': otherUserId,
    })
        .asStream()
        .map((data) => (data as List)
        .map((json) => models.Message.fromJson(json))
        .toList());
  }

  // Fetch a list of chat rooms (users with whom the current user has chatted)
  // This is a simplified approach, a dedicated 'chat_rooms' table would be more robust.
  Future<List<models.ChatRoom>> getChatRooms(String currentUserId) async {
    // Keep existing logic for getting participant IDs...
    final List<Map<String, dynamic>> sentMessages = await _supabaseClient
        .from('messages')
        .select('receiver_id, created_at, content, image_url')
        .eq('sender_id', currentUserId)
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> receivedMessages = await _supabaseClient
        .from('messages')
        .select('sender_id, created_at, content, image_url')
        .eq('receiver_id', currentUserId)
        .order('created_at', ascending: false);

    Set<String> participantIds = {};
    for (var msg in sentMessages) {
      participantIds.add(msg['receiver_id'] as String);
    }
    for (var msg in receivedMessages) {
      participantIds.add(msg['sender_id'] as String);
    }
    participantIds.remove(currentUserId);

    List<models.ChatRoom> chatRooms = [];
    for (String participantId in participantIds) {
      // Get last message
      final latestMessageQuery = await _supabaseClient
          .from('messages')
          .select('*')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$participantId),and(sender_id.eq.$participantId,receiver_id.eq.$currentUserId)')
          .order('created_at', ascending: false)
          .limit(1);

      models.Message? lastMessage;
      if (latestMessageQuery.isNotEmpty) {
        lastMessage = models.Message.fromJson(latestMessageQuery.first);
      }

      // Get unread count - NEW
      final unreadCount = await getUnreadMessageCount(currentUserId, participantId);

      // Get user profile
      final userProfile = await _supabaseClient
          .from('users')
          .select('username, profile_image_url')
          .eq('id', participantId)
          .single();

      // Calculate status - NEW
      final status = calculateChatStatus(
        lastMessage: lastMessage,
        currentUserId: currentUserId,
        unreadCount: unreadCount,
      );

      chatRooms.add(models.ChatRoom(
        id: ([currentUserId, participantId]..sort()).join('_'),
        otherUserId: participantId,
        otherUsername: userProfile['username'] as String? ?? 'Unknown User',
        otherUserProfileUrl: userProfile['profile_image_url'] as String?,
        lastMessage: lastMessage,
        unreadCount: unreadCount, // NEW
        status: status, // NEW
      ));
    }

    // Sort by last message time
    chatRooms.sort((a, b) {
      if (a.lastMessage == null && b.lastMessage == null) return 0;
      if (a.lastMessage == null) return 1;
      if (b.lastMessage == null) return -1;
      return b.lastMessage!.createdAt.compareTo(a.lastMessage!.createdAt);
    });

    return chatRooms;
  }
}