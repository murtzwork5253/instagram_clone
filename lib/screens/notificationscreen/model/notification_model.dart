// models/notification_model.dart
class NotificationModel {
  final String id;
  final String? recipientId;
  final String? senderId;
  final String type;
  final String? postId;
  final bool isRead;
  final DateTime createdAt;

  // Additional fields for displaying notification details
  final String? senderName;
  final String? senderAvatar;
  final String? postContent;
  final String? postImage;

  NotificationModel({
    required this.id,
    this.recipientId,
    this.senderId,
    required this.type,
    this.postId,
    required this.isRead,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
    this.postContent,
    this.postImage,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      recipientId: map['recipient_id'],
      senderId: map['sender_id'],
      type: map['type'] ?? '',
      postId: map['post_id'],
      isRead: map['is_read'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
      senderName: map['sender_name'],
      senderAvatar: map['sender_avatar'],
      postContent: map['post_content'],
      postImage: map['post_image'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'sender_id': senderId,
      'type': type,
      'post_id': postId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// models/notification_preferences_model.dart
class NotificationPreferencesModel {
  final String userId;
  final bool likes;
  final bool comments;
  final bool follows;
  final bool mentions;
  final bool stories;
  final bool messages;
  final bool calls;

  NotificationPreferencesModel({
    required this.userId,
    required this.likes,
    required this.comments,
    required this.follows,
    required this.mentions,
    required this.stories,
    required this.messages,
    required this.calls,
  });

  factory NotificationPreferencesModel.fromMap(Map<String, dynamic> map) {
    return NotificationPreferencesModel(
      userId: map['user_id'] ?? '',
      likes: map['likes'] ?? true,
      comments: map['comments'] ?? true,
      follows: map['follows'] ?? true,
      mentions: map['mentions'] ?? true,
      stories: map['stories'] ?? true,
      messages: map['messages'] ?? true,
      calls: map['calls'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'likes': likes,
      'comments': comments,
      'follows': follows,
      'mentions': mentions,
      'stories': stories,
      'messages': messages,
      'calls': calls,
    };
  }
}

// Notification types enum
enum NotificationType {
  like('like'),
  comment('comment'),
  follow('follow'),
  mention('mention'),
  story('story'),
  reelLike('reel_like'),
  storyLike('story_like'),
  commentLike('comment_like'),
  reelComment('reel_comment'),
  messages('messages'),
  calls('calls');

  const NotificationType(this.value);
  final String value;
}