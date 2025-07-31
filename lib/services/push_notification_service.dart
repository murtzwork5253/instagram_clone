import 'package:Instagram/screens/calling/call_manager.dart';
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
  static String? _currentFCMToken;

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    try {
      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request permissions
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('User denied notification permissions');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get and store FCM token
      _currentFCMToken = await messaging.getToken();
      print('FCM Token initialized: ${_currentFCMToken?.substring(0, 20)}...');

      // Handle foreground messages (from server)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received foreground message: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // Handle background message taps (from server)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('App opened from background notification: ${message.messageId}');
        _handleNotificationTap(message.data);
      });

      // Handle app launch from notification (from server)
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          print('App opened from terminated state notification: ${message.messageId}');
          _handleNotificationTap(message.data);
        }
      });

      // Handle token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: ${newToken.substring(0, 20)}...');
        _currentFCMToken = newToken;
        _updateFCMTokenForAllUsers(newToken);
      });

      print('Push notification service initialized successfully');
    } catch (e) {
      print('Error initializing push notification service: $e');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      // Extract notification content from message data or notification payload
      String title = message.notification?.title ??
          message.data['title'] ??
          _getDefaultTitle(message.data);

      String body = message.notification?.body ??
          message.data['body'] ??
          _getDefaultBody(message.data);

      print('Showing notification - Title: $title, Body: $body');

      // Show local notification when app is in foreground (server-sent messages only)
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
        message.hashCode,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      print('Error handling foreground message: $e');
    }
  }

  // Generate appropriate title based on notification type
  static String _getDefaultTitle(Map<String, dynamic> data) {
    final type = data['type'];
    final senderName = data['sender_name'] ?? 'Someone';

    switch (type) {
      case 'like':
        return '$senderName liked your post';
      case 'post_comment':
        return '$senderName commented on your post';
      case 'reel_like':
        return '$senderName liked your reel';
      case 'reel_comment':
        return '$senderName commented on your reel';
      case 'comment_like':
        return '$senderName liked your comment';
      case 'follow':
        return '$senderName started following you';
      case 'mention':
        return '$senderName mentioned you';
      case 'story_like':
        return '$senderName liked your story';
      case 'messages':
        return '$senderName sends you a new message';
      case 'calls':
        return '$senderName is calling you';
      default:
        return 'New Notification';
    }
  }

  // Generate appropriate body based on notification type
  static String _getDefaultBody(Map<String, dynamic> data) {
    final type = data['type'];
    final senderName = data['sender_name'] ?? 'Someone';
    final commentText = data['comment_text'];

    switch (type) {
      case 'like':
        return 'Your post received a new like';
      case 'post_comment':
        if (commentText != null && commentText.isNotEmpty) {
          // Truncate comment if too long
          final truncated = commentText.length > 50
              ? '${commentText.substring(0, 50)}...'
              : commentText;
          return '"$truncated"';
        }
        return 'Someone commented on your post';
      case 'reel_like':
        return 'Your reel received a new like';
      case 'reel_comment':
        if (commentText != null && commentText.isNotEmpty) {
          final truncated = commentText.length > 50
              ? '${commentText.substring(0, 50)}...'
              : commentText;
          return '"$truncated"';
        }
        return 'Someone commented on your reel';
      case 'comment_like':
        return 'Someone liked your comment';
      case 'follow':
        return 'You have a new follower';
      case 'mention':
        return 'You were mentioned in a post';
      case 'story_like':
        return 'Someone liked your story';
      case 'messages':
        return 'You have a new message';
      case 'calls':
        return 'You have a new call';
      default:
        return 'You have a new notification';
    }
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
          try {
            final data = jsonDecode(payload);
            _handleNotificationTap(data);
          } catch (e) {
            print('Error parsing notification payload: $e');
          }
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

  // Add user to notification listeners and store FCM token
  static Future<void> addUserToNotificationListener(String userId) async {
    if (_loggedInUserIds.contains(userId)) {
      print('User $userId already registered for notifications');
      return;
    }

    try {
      // Store FCM token for this user (for server-side notifications)
      if (_currentFCMToken != null) {
        await _storeFCMTokenForUser(_currentFCMToken!, userId);
      }

      // Add to logged in users list
      _loggedInUserIds.add(userId);
      print('Added user $userId to notification listeners');
    } catch (e) {
      print('Error adding user to notification listener: $e');
    }
  }

  // Remove user from notification listeners
  static Future<void> removeUserFromNotificationListener(String userId) async {
    try {
      // Remove from logged in users list
      _loggedInUserIds.remove(userId);
      print('Removed user $userId from notification listeners');
    } catch (e) {
      print('Error removing user from notification listener: $e');
    }
  }

  // Update notification listeners for all stored accounts
  static Future<void> updateNotificationListenersForAllAccounts(List<String> userIds) async {
    print('Updating notification listeners for all accounts: $userIds');

    try {
      // Remove listeners for users no longer logged in
      final usersToRemove = _loggedInUserIds.where((id) => !userIds.contains(id)).toList();
      for (String userId in usersToRemove) {
        await removeUserFromNotificationListener(userId);
      }

      // Add listeners for new users
      for (String userId in userIds) {
        await addUserToNotificationListener(userId);
      }
    } catch (e) {
      print('Error updating notification listeners for all accounts: $e');
    }
  }

  // Store FCM token for a specific user (used by server to send notifications)
  static Future<void> _storeFCMTokenForUser(String token, String userId) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({
        'fcm_token': token,
        'fcm_token_updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', userId);
      print('FCM token stored for user $userId');
    } catch (e) {
      print('Error storing FCM token for user $userId: $e');
    }
  }

  // Update FCM token for all logged-in users
  static Future<void> _updateFCMTokenForAllUsers(String token) async {
    for (String userId in _loggedInUserIds) {
      await _storeFCMTokenForUser(token, userId);
    }
  }

  static void _handleNotificationTap(Map<String, dynamic> data) async{
    if (_navigatorKey.currentContext == null) return;

    final type = data['type'];
    final postId = data['post_id'];
    final senderId = data['sender_id'];
    final recipientId = data['recipient_id'];

    print('Handling notification tap - Type: $type, PostId: $postId, SenderId: $senderId');

    // Navigate based on notification type
    switch (type) {
      case 'like':
      case 'post_comment':
      case 'reel_like':
      case 'reel_comment':
        if (postId != null) {
          // Navigate to post/reel detail screen
          Navigator.pushNamed(
            _navigatorKey.currentContext!,
            '/post_detail', // Make sure this route exists
            arguments: {
              'postId': postId,
              'userId': recipientId,
            },
          );
        } else {
          _navigateToNotifications(recipientId);
        }
        break;
      case 'follow':
        if (senderId != null) {
          // Navigate to sender's profile
          Navigator.pushNamed(
            _navigatorKey.currentContext!,
            '/profile', // Make sure this route exists
            arguments: {
              'userId': senderId,
              'currentUserId': recipientId,
            },
          );
        } else {
          _navigateToNotifications(recipientId);
        }
        break;
      case 'mention':
        if (postId != null) {
          Navigator.pushNamed(
            _navigatorKey.currentContext!,
            '/post_detail',
            arguments: {
              'postId': postId,
              'userId': recipientId,
            },
          );
        } else {
          _navigateToNotifications(recipientId);
        }
        break;
      // case 'story':
      case 'story_like':
        if (senderId != null) {
          // Navigate to story view
          Navigator.pushNamed(
            _navigatorKey.currentContext!,
            '/story_view', // Make sure this route exists
            arguments: {
              'userId': senderId,
              'currentUserId': recipientId,
            },
          );
        } else {
          _navigateToNotifications(recipientId);
        }
        break;
      case 'calls':
        final callManager = CallManager();

        // IMPORTANT: Check the database for an active call to refresh the app's state
        final activeCall = await callManager.callService.checkForActiveCall();

        if (activeCall != null) {
          // If a call is found, use a method to rejoin it
          await callManager.rejoinCall(_navigatorKey.currentContext!, activeCall);
        }
        break;
      default:
        _navigateToNotifications(recipientId);
    }
  }

  static void _navigateToNotifications(String? userId) {
    Navigator.pushNamed(
      _navigatorKey.currentContext!,
      '/notifications', // Make sure this route exists
      arguments: {'userId': userId},
    );
  }

  // Get list of currently listening user IDs
  static List<String> get listeningUserIds => List.from(_loggedInUserIds);

  // Get current FCM token
  static String? get currentFCMToken => _currentFCMToken;

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
    // For iOS badge count, you might need to use flutter_app_badger plugin
  }
}