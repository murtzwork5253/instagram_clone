// screens/notification_screen.dart
import 'package:Instagram/screens/homescreen/story_view_screen.dart';
import 'package:Instagram/screens/notificationscreen/service/notification_service.dart';
import 'package:Instagram/screens/profilescreen/other_user_profile_screen.dart';
import 'package:Instagram/screens/profilescreen/single_post_view.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'model/notification_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final String currentUserId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    // Mark all notifications as read when screen is opened
    _notificationService.markAllAsRead(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showNotificationSettings(context),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.watchNotifications(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationTile(
                notification: notification,
                onTap: () => _handleNotificationTap(notification),
                onDelete: () => _deleteNotification(notification.id),
              );
            },
          );
        },
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read if not already read
    if (!notification.isRead) {
      _notificationService.markAsRead(notification.id);
    }

    // Navigate based on notification type
    switch (notification.type) {
      case 'like':
      case 'comment':
      case 'reel_like':
        if (notification.postId != null) {
          // Navigate to post detail screen
          _navigateToPost(notification.postId!);
        }
        break;
      case 'follow':
      // Navigate to user profile
        if (notification.senderId != null) {
          _navigateToProfile(notification.senderId!);
        }
        break;
      case 'story':
      case 'story_like':
        if (notification.postId != null) {
          // Navigate to story view
          _navigateToStory(notification.postId!);
        }
        break;
      case 'mention':
        if (notification.postId != null) {
          // Navigate to post where user was mentioned
          _navigateToPost(notification.postId!);
        }
        break;
    }
  }

  void _navigateToPost(String postId) {
    // Implement navigation to post detail screen
    // Navigator.push(context, MaterialPageRoute(builder: (context) => SinglePostView(initialIndex: index,postId: postId)));
  }

  void _navigateToProfile(String userId) {
    // Implement navigation to user profile screen
    Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfileScreen(userId: userId)));
  }

  void _navigateToStory(String storyId) {
    // Implement navigation to story view screen
    // Navigator.push(context, MaterialPageRoute(builder: (context) => StoryViewScreen(storyId: storyId)));
  }

  void _deleteNotification(String notificationId) {
    _notificationService.deleteNotification(notificationId);
  }

  void _showNotificationSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationSettingsScreen(),
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NotificationTile({
    Key? key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  String? _getFullProfileImageUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    if (avatarPath.startsWith('http')) return avatarPath;
    // Replace with your actual Supabase project URL
    const supabaseBaseUrl = 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/';
    return '$supabaseBaseUrl$avatarPath';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage: _getFullProfileImageUrl(notification.senderAvatar) != null
              ? NetworkImage(_getFullProfileImageUrl(notification.senderAvatar)!)
              : null,
          child: notification.senderAvatar == null
              ? Text(notification.senderName?.substring(0, 1) ?? '?')
              : null,
        ),
        title: Text(
          _getNotificationTitle(notification),
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        // subtitle: Column(
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //     if (notification.postContent != null)
        //       Text(
        //         notification.postContent!,
        //         maxLines: 2,
        //         overflow: TextOverflow.ellipsis,
        //         style: const TextStyle(color: Colors.grey),
        //       ),
        //     Text(
        //       _getTimeAgo(notification.createdAt),
        //       style: const TextStyle(color: Colors.grey, fontSize: 12),
        //     ),
        //   ],
        // ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            if (notification.postImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  notification.postImage!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getNotificationTitle(NotificationModel notification) {
    final senderName = notification.senderName ?? 'Someone';

    switch (notification.type) {
      case 'like':
        return '$senderName liked your post';
      case 'reel_like':
        return '$senderName liked your reel';
      case 'story_like':
        return '$senderName liked your story';
      case 'comment':
        return '$senderName commented on your post';
      case 'comment_like':
        return '$senderName liked your comment';
      case 'follow':
        return '$senderName started following you';
      case 'mention':
        return '$senderName mentioned you in a post';
      case 'story':
        return '$senderName posted a new story';
      default:
        return 'New notification';
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Notification Settings Screen
class NotificationSettingsScreen extends StatefulWidget {
  @override
  _NotificationSettingsScreenState createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final String currentUserId = Supabase.instance.client.auth.currentUser!.id;

  NotificationPreferencesModel? _preferences;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() async {
    final preferences = await _notificationService.getUserNotificationPreferences(currentUserId);
    setState(() {
      _preferences = preferences;
      _isLoading = false;
    });
  }

  void _updatePreference(String type, bool value) async {
    if (_preferences == null) return;

    NotificationPreferencesModel updatedPreferences;

    switch (type) {
      case 'likes':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: value,
          comments: _preferences!.comments,
          follows: _preferences!.follows,
          mentions: _preferences!.mentions,
          stories: _preferences!.stories,
        );
        break;
      case 'comments':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: _preferences!.likes,
          comments: value,
          follows: _preferences!.follows,
          mentions: _preferences!.mentions,
          stories: _preferences!.stories,
        );
        break;
      case 'follows':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: _preferences!.likes,
          comments: _preferences!.comments,
          follows: value,
          mentions: _preferences!.mentions,
          stories: _preferences!.stories,
        );
        break;
      case 'mentions':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: _preferences!.likes,
          comments: _preferences!.comments,
          follows: _preferences!.follows,
          mentions: value,
          stories: _preferences!.stories,
        );
        break;
      case 'stories':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: _preferences!.likes,
          comments: _preferences!.comments,
          follows: _preferences!.follows,
          mentions: _preferences!.mentions,
          stories: value,
        );
        break;
      default:
        return;
    }

    await _notificationService.updateNotificationPreferences(updatedPreferences);
    setState(() {
      _preferences = updatedPreferences;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _preferences == null
          ? const Center(child: Text('Error loading preferences'))
          : ListView(
        children: [
          SwitchListTile(
            title: const Text('Likes'),
            subtitle: const Text('Get notified when someone likes your content'),
            value: _preferences!.likes,
            onChanged: (value) => _updatePreference('likes', value),
          ),
          SwitchListTile(
            title: const Text('Comments'),
            subtitle: const Text('Get notified when someone comments on your posts'),
            value: _preferences!.comments,
            onChanged: (value) => _updatePreference('comments', value),
          ),
          SwitchListTile(
            title: const Text('Follows'),
            subtitle: const Text('Get notified when someone follows you'),
            value: _preferences!.follows,
            onChanged: (value) => _updatePreference('follows', value),
          ),
          SwitchListTile(
            title: const Text('Mentions'),
            subtitle: const Text('Get notified when someone mentions you'),
            value: _preferences!.mentions,
            onChanged: (value) => _updatePreference('mentions', value),
          ),
          SwitchListTile(
            title: const Text('Stories'),
            subtitle: const Text('Get notified when someone posts a story'),
            value: _preferences!.stories,
            onChanged: (value) => _updatePreference('stories', value),
          ),
        ],
      ),
    );
  }
}