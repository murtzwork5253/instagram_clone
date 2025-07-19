import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  static late GlobalKey<NavigatorState> _navigatorKey;
  static Map<String, RealtimeChannel> _notificationChannels = {};
  static List<String> _loggedInUserIds = [];

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    await Firebase.initializeApp();
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions (Android 13+ and iOS)
    await messaging.requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Handle token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _storeFCMTokenForAllUsers(newToken);
    });

    // Handle background/terminated app launch from notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationTap(message.data);
      }
    });
  }

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null) {
          final data = jsonDecode(payload);
          _handleNotificationTap(data);
        }
      },
    );

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // NEW METHOD: Add a user to notification listening
  static Future<void> addUserToNotificationListener(String userId) async {
    if (_loggedInUserIds.contains(userId)) {
      print('User $userId already has notification listener');
      return;
    }

    try {
      // Store FCM token for this user
      String? token = await FirebaseMessaging.instance.getToken();
      await _storeFCMTokenForUser(token, userId);

      // Add to logged in users list
      _loggedInUserIds.add(userId);

      // Create notification channel for this user
      final channel = Supabase.instance.client
          .channel('notifications:$userId')
          .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: userId,
        ),
        callback: (payload) {
          _handleRealtimeNotification(payload.newRecord, userId);
        },
      )
          .subscribe();

      _notificationChannels[userId] = channel;
      print('Added notification listener for user: $userId');
    } catch (e) {
      print('Error adding user to notification listener: $e');
    }
  }

  // NEW METHOD: Remove a user from notification listening
  static Future<void> removeUserFromNotificationListener(String userId) async {
    if (!_loggedInUserIds.contains(userId)) {
      print('User $userId not in notification listeners');
      return;
    }

    try {
      // Unsubscribe from channel
      if (_notificationChannels.containsKey(userId)) {
        await _notificationChannels[userId]!.unsubscribe();
        _notificationChannels.remove(userId);
      }

      // Remove from logged in users list
      _loggedInUserIds.remove(userId);

      print('Removed notification listener for user: $userId');
    } catch (e) {
      print('Error removing user from notification listener: $e');
    }
  }

  // NEW METHOD: Update notification listeners for all stored accounts
  static Future<void> updateNotificationListenersForAllAccounts(List<String> userIds) async {
    print('Updating notification listeners for all accounts: $userIds');

    // Remove listeners for users no longer logged in
    final usersToRemove = _loggedInUserIds.where((id) => !userIds.contains(id)).toList();
    for (String userId in usersToRemove) {
      await removeUserFromNotificationListener(userId);
    }

    // Add listeners for new users
    for (String userId in userIds) {
      await addUserToNotificationListener(userId);
    }
  }

  // Store FCM token for a specific user
  static Future<void> _storeFCMTokenForUser(String? token, String userId) async {
    if (token == null) return;

    try {
      await Supabase.instance.client
          .from('users')
          .update({
        'fcm_token': token,
        'fcm_token_updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', userId);
    } catch (e) {
      print('Error storing FCM token for user $userId: $e');
    }
  }

  // Store FCM token for all logged-in users
  static Future<void> _storeFCMTokenForAllUsers(String? token) async {
    if (token == null) return;

    for (String userId in _loggedInUserIds) {
      await _storeFCMTokenForUser(token, userId);
    }
  }

  static Future<void> _handleRealtimeNotification(Map<String, dynamic> notification, String recipientUserId) async {
    try {
      // Fetch additional details for the notification
      final notificationDetails = await _getNotificationDetails(notification);

      // Show local notification with recipient context
      await _showLocalNotification(notificationDetails, recipientUserId);

    } catch (e) {
      print('Error handling realtime notification: $e');
    }
  }

  static Future<Map<String, dynamic>> _getNotificationDetails(Map<String, dynamic> notification) async {
    try {
      // Get sender details
      Map<String, dynamic>? sender;
      if (notification['sender_id'] != null) {
        sender = await Supabase.instance.client
            .from('users')
            .select('id, full_name, profile_image_url, username')
            .eq('id', notification['sender_id'])
            .maybeSingle();
      }

      // Get recipient details
      Map<String, dynamic>? recipient;
      if (notification['recipient_id'] != null) {
        recipient = await Supabase.instance.client
            .from('users')
            .select('id, full_name, profile_image_url, username')
            .eq('id', notification['recipient_id'])
            .maybeSingle();
      }

      // Get post details if applicable
      Map<String, dynamic>? post;
      if (notification['post_id'] != null) {
        post = await Supabase.instance.client
            .from('posts')
            .select('id, caption, image_url')
            .eq('id', notification['post_id'])
            .maybeSingle();
      }

      return {
        ...notification,
        'sender': sender,
        'recipient': recipient,
        'post': post,
      };
    } catch (e) {
      print('Error getting notification details: $e');
      return notification;
    }
  }

  static Future<void> _showLocalNotification(Map<String, dynamic> notificationData, String recipientUserId) async {
    final String title = _generateNotificationTitle(notificationData, recipientUserId);
    final String body = _generateNotificationBody(notificationData, recipientUserId);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      '${notificationData['id']}_$recipientUserId'.hashCode,
      title,
      body,
      notificationDetails,
      payload: jsonEncode({
        'type': notificationData['type'],
        'sender_id': notificationData['sender_id'],
        'post_id': notificationData['post_id'],
        'notification_id': notificationData['id'],
        'recipient_id': recipientUserId,
      }),
    );
  }

  static String _generateNotificationTitle(Map<String, dynamic> data, String recipientUserId) {
    final senderName = data['sender']?['full_name'] ?? data['sender']?['username'] ?? 'Someone';
    final recipientName = data['recipient']?['username'] ?? 'Account';
    final type = data['type'] ?? '';

    switch (type) {
      case 'like':
        return '($recipientName) $senderName liked your post';
      case 'post_comment':
        return '($recipientName) $senderName commented on your post';
      case 'reel_comment':
        return '($recipientName) $senderName commented on your reel';
      case 'follow':
        return '($recipientName) $senderName started following you';
      case 'mention':
        return '($recipientName) $senderName mentioned you';
      case 'story':
        return '($recipientName) $senderName viewed your story';
      case 'reel_like':
        return '($recipientName) $senderName liked your reel';
      case 'story_like':
        return '($recipientName) $senderName liked your story';
      case 'comment_like':
        return '($recipientName) $senderName liked your comment';
      default:
        return '($recipientName) New notification';
    }
  }

  static String _generateNotificationBody(Map<String, dynamic> data, String recipientUserId) {
    final type = data['type'] ?? '';
    final postContent = data['post']?['caption'];
    final senderName = data['sender']?['full_name'] ?? data['sender']?['username'] ?? 'Someone';

    switch (type) {
      case 'like':
      case 'reel_like':
        return postContent != null && postContent.isNotEmpty
            ? '"${postContent.length > 50 ? postContent.substring(0, 50) + '...' : postContent}"'
            : 'Check out your post';
      case 'post_comment':
        return 'Tap to see the comment';
      case 'reel_comment':
        return 'Tap to see the comment';
      case 'follow':
        return 'Tap to view $senderName\'s profile';
      case 'mention':
        return 'You were mentioned in a post by $senderName';
      case 'story':
        return 'Your story has a new view';
      case 'story_like':
        return '$senderName liked your story';
      case 'comment_like':
        return 'Your comment received a like';
      default:
        return 'You have a new notification';
    }
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    if (_navigatorKey.currentContext == null) return;

    final type = data['type'];
    final postId = data['post_id'];
    final senderId = data['sender_id'];
    final recipientId = data['recipient_id'];

    // You might want to switch to the account that received the notification
    // before navigating to the relevant screen

    switch (type) {
      case 'like':
      case 'comment':
      case 'reel_like':
        if (postId != null) {
          Navigator.pushNamed(
            _navigatorKey.currentContext!,
            '/post_detail',
            arguments: {'postId': postId, 'switchToAccount': recipientId},
          );
        }
        break;
      case 'follow':
        if (senderId != null) {
          Navigator.pushNamed(
            _navigatorKey.currentContext!,
            '/profile',
            arguments: {'userId': senderId, 'switchToAccount': recipientId},
          );
        }
        break;
      case 'mention':
        if (postId != null) {
          Navigator.pushNamed(
            _navigatorKey.currentContext!,
            '/post_detail',
            arguments: {'postId': postId, 'switchToAccount': recipientId},
          );
        }
        break;
      case 'story':
      case 'story_like':
        Navigator.pushNamed(
          _navigatorKey.currentContext!,
          '/story_view',
          arguments: {'userId': senderId, 'switchToAccount': recipientId},
        );
        break;
      default:
        Navigator.pushNamed(
          _navigatorKey.currentContext!,
          '/notifications',
          arguments: {'switchToAccount': recipientId},
        );
    }
  }

  // Method to send notification to specific user
  static Future<void> sendNotificationToUser({
    required String recipientId,
    required String senderId,
    required String type,
    String? postId,
  }) async {
    try {
      // First create the notification in your database
      await Supabase.instance.client.from('notifications').insert({
        'recipient_id': recipientId,
        'sender_id': senderId,
        'type': type,
        'post_id': postId,
        'is_read': false,
      });

      // The real-time listener will automatically handle showing the notification
      // to the recipient if they're logged in on this device

    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Method to send notification to multiple users
  static Future<void> sendNotificationToMultipleUsers({
    required List<String> recipientIds,
    required String senderId,
    required String type,
    String? postId,
  }) async {
    try {
      final notifications = recipientIds.map((recipientId) => {
        'recipient_id': recipientId,
        'sender_id': senderId,
        'type': type,
        'post_id': postId,
        'is_read': false,
      }).toList();

      await Supabase.instance.client.from('notifications').insert(notifications);
    } catch (e) {
      print('Error sending notifications to multiple users: $e');
    }
  }

  // Get list of currently listening user IDs
  static List<String> get listeningUserIds => List.from(_loggedInUserIds);

  // Clean up resources
  static Future<void> dispose() async {
    for (RealtimeChannel channel in _notificationChannels.values) {
      await channel.unsubscribe();
    }
    _notificationChannels.clear();
    _loggedInUserIds.clear();
  }

  // Update badge count (iOS)
  static Future<void> updateBadgeCount(int count) async {
    if (count == 0) {
      await _localNotificationsPlugin.cancelAll();
    }
    // For iOS badge count, you might need to use a plugin like flutter_app_badger
  }
}