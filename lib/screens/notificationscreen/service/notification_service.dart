// services/notification_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create a notification with automatic push notification
  Future<void> createNotification({
    required String recipientId,
    required String senderId,
    required String type,
    String? postId,
  }) async {
    try {
      // Don't send notification to self
      if (recipientId == senderId) return;

      // Check if recipient wants this type of notification
      final preferences = await getUserNotificationPreferences(recipientId);

      bool shouldNotify = false;
      switch (type) {
        case 'like':
        case 'reel_like':
        case 'story_like':
        case 'comment_like':
          shouldNotify = preferences.likes;
          break;
        case 'post_comment':
        case 'reel_comment':
        case 'comment':
          shouldNotify = preferences.comments;
          break;
        case 'follow':
          shouldNotify = preferences.follows;
          break;
        case 'mention':
          shouldNotify = preferences.mentions;
          break;
        case 'story':
          shouldNotify = preferences.stories;
          break;
      }

      if (!shouldNotify) return;

      // Check if similar notification already exists to avoid duplicates
      final existingNotification = await _supabase
          .from('notifications')
          .select()
          .eq('recipient_id', recipientId)
          .eq('sender_id', senderId)
          .eq('type', type)
          .eq('post_id', postId ?? '')
          .maybeSingle();

      if (existingNotification != null) {
        // Update existing notification timestamp instead of creating duplicate
        await _supabase
            .from('notifications')
            .update({'created_at': DateTime.now().toIso8601String()})
            .eq('id', existingNotification['id']);
        return;
      }

      // Create notification in database
      final response = await _supabase.from('notifications').insert({
        'recipient_id': recipientId,
        'sender_id': senderId,
        'type': type,
        'post_id': postId,
        'is_read': false,
      }).select().single();

      print('Notification created: ${response['id']}');

      // The push notification will be handled automatically by the real-time listener
      // in PushNotificationService

    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Batch create notifications (e.g., for story views, post likes from multiple users)
  Future<void> createBatchNotifications({
    required List<String> recipientIds,
    required String senderId,
    required String type,
    String? postId,
  }) async {
    try {
      final validRecipients = <String>[];

      // Filter recipients based on their preferences
      for (final recipientId in recipientIds) {
        if (recipientId == senderId) continue;

        final preferences = await getUserNotificationPreferences(recipientId);

        bool shouldNotify = false;
        switch (type) {
          case 'like':
          case 'reel_like':
          case 'story_like':
          case 'comment_like':
            shouldNotify = preferences.likes;
            break;
          case 'post_comment':
          case 'reel_comment':
          case 'comment':
            shouldNotify = preferences.comments;
            break;
          case 'follow':
            shouldNotify = preferences.follows;
            break;
          case 'mention':
            shouldNotify = preferences.mentions;
            break;
          case 'story':
            shouldNotify = preferences.stories;
            break;
        }

        if (shouldNotify) {
          validRecipients.add(recipientId);
        }
      }

      if (validRecipients.isEmpty) return;

      // Create notifications
      final notifications = validRecipients.map((recipientId) => {
        'recipient_id': recipientId,
        'sender_id': senderId,
        'type': type,
        'post_id': postId,
        'is_read': false,
      }).toList();

      await _supabase.from('notifications').insert(notifications);

    } catch (e) {
      print('Error creating batch notifications: $e');
    }
  }

  // Get user notifications with sender and post details
  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('''
            *,
            sender:sender_id(id, full_name, profile_image_url),
            post:post_id(id, caption, image_url)
          ''')
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .limit(50); // Limit to recent notifications

      return response.map<NotificationModel>((item) {
        return NotificationModel.fromMap({
          ...item,
          'sender_name': item['sender']?['full_name'],
          'sender_avatar': item['sender']?['profile_image_url'],
          'post_content': item['post']?['caption'],
          'post_image': item['post']?['image_url'],
        });
      }).toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId)
          .eq('is_read', false);

      return response.length ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Stream unread count for real-time updates
  Stream<int> watchUnreadCount(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('[recipient_id,is_read]', [userId,false])
        .map((data) => data.length);
  }

  // Get user notification preferences
  Future<NotificationPreferencesModel> getUserNotificationPreferences(String userId) async {
    try {
      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Create default preferences if none exist
        await createDefaultNotificationPreferences(userId);
        return NotificationPreferencesModel(
          userId: userId,
          likes: true,
          comments: true,
          follows: true,
          mentions: true,
          stories: true,
        );
      }

      return NotificationPreferencesModel.fromMap(response);
    } catch (e) {
      print('Error fetching notification preferences: $e');
      return NotificationPreferencesModel(
        userId: userId,
        likes: true,
        comments: true,
        follows: true,
        mentions: true,
        stories: true,
      );
    }
  }

  // Create default notification preferences
  Future<void> createDefaultNotificationPreferences(String userId) async {
    try {
      await _supabase.from('notification_preferences').insert({
        'user_id': userId,
        'likes': true,
        'comments': true,
        'follows': true,
        'mentions': true,
        'stories': true,
      });
    } catch (e) {
      print('Error creating default notification preferences: $e');
    }
  }

  // Update notification preferences
  Future<void> updateNotificationPreferences(NotificationPreferencesModel preferences) async {
    try {
      await _supabase
          .from('notification_preferences')
          .upsert(preferences.toMap());
    } catch (e) {
      print('Error updating notification preferences: $e');
    }
  }

  // Listen to real-time notifications
  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((data) async {
      List<NotificationModel> notifications = [];
      for (var item in data) {
        final notificationWithDetails = await _getNotificationWithDetails(item);
        notifications.add(notificationWithDetails);
      }
      return notifications;
    });
  }

  // Helper method to get notification with sender and post details
  Future<NotificationModel> _getNotificationWithDetails(Map<String, dynamic> notification) async {
    try {
      // Get sender details
      Map<String, dynamic>? sender;
      if (notification['sender_id'] != null) {
        sender = await _supabase
            .from('users')
            .select('id, full_name, profile_image_url')
            .eq('id', notification['sender_id'])
            .maybeSingle();
      }

      // Get post details
      Map<String, dynamic>? post;
      if (notification['post_id'] != null) {
        post = await _supabase
            .from('posts')
            .select('id, caption, image_url')
            .eq('id', notification['post_id'])
            .maybeSingle();
      }

      return NotificationModel.fromMap({
        ...notification,
        'sender_name': sender?['full_name'],
        'sender_avatar': sender?['profile_image_url'],
        'post_content': post?['caption'],
        'post_image': post?['image_url'],
      });
    } catch (e) {
      print('Error getting notification details: $e');
      return NotificationModel.fromMap(notification);
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clean up old notifications (call periodically)
  Future<void> cleanupOldNotifications(String userId, {int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      await _supabase
          .from('notifications')
          .delete()
          .eq('recipient_id', userId)
          .lt('created_at', cutoffDate.toIso8601String());
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }

  // Get notifications by type
  Future<List<NotificationModel>> getNotificationsByType(String userId, String type) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('''
            *,
            sender:sender_id(id, full_name, profile_image_url),
            post:post_id(id, caption, image_url)
          ''')
          .eq('recipient_id', userId)
          .eq('type', type)
          .order('created_at', ascending: false)
          .limit(20);

      return response.map<NotificationModel>((item) {
        return NotificationModel.fromMap({
          ...item,
          'sender_name': item['sender']?['full_name'],
          'sender_avatar': item['sender']?['profile_image_url'],
          'post_content': item['post']?['caption'],
          'post_image': item['post']?['image_url'],
        });
      }).toList();
    } catch (e) {
      print('Error fetching notifications by type: $e');
      return [];
    }
  }
}