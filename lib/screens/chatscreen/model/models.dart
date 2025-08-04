import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // For JSON parsing

// --- Data Models ---
// Message Model
class Message {
  final String id;
  final String? senderId;
  final String? receiverId;
  final String? content;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? seenAt;// NEW FIELD
  final Map<String, dynamic>? sharedPost;
  final Map<String, dynamic>? sharedReel;

  Message({
    required this.id,
    this.senderId,
    this.receiverId,
    this.content,
    this.imageUrl,
    this.sharedPost,
    required this.isRead,
    required this.createdAt,
    this.seenAt, // NEW FIELD
    this.sharedReel,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    print('Raw message JSON: ' + json.toString()); // DEBUG
    dynamic sharedPostRaw = json['shared_post'];
    Map<String, dynamic>? sharedPost;
    if (sharedPostRaw != null) {
      if (sharedPostRaw is String) {
        try {
          sharedPost = Map<String, dynamic>.from(jsonDecode(sharedPostRaw));
        } catch (_) {
          sharedPost = null;
        }
      } else if (sharedPostRaw is Map) {
        sharedPost = Map<String, dynamic>.from(sharedPostRaw);
      }
    }
    print('Parsed sharedPost: ' + sharedPost.toString()); // DEBUG

    dynamic sharedReelRaw = json['shared_reel']; // NEW
    Map<String, dynamic>? sharedReel; // NEW
    if (sharedReelRaw != null) { // NEW
      if (sharedReelRaw is String) { // NEW
        try { // NEW
          sharedReel = Map<String, dynamic>.from(jsonDecode(sharedReelRaw)); // NEW
        } catch (_) { // NEW
          sharedReel = null; // NEW
        } // NEW
      } else if (sharedReelRaw is Map) { // NEW
        sharedReel = Map<String, dynamic>.from(sharedReelRaw); // NEW
      } // NEW
    } // NEW
    return Message(
      id: json['id'] as String,
      senderId: json['sender_id'] as String?,
      receiverId: json['receiver_id'] as String?,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      sharedPost: sharedPost,
      sharedReel: sharedReel, // NEW
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      seenAt: json['seen_at'] != null ? DateTime.parse(json['seen_at'] as String).toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'image_url': imageUrl,
      'shared_post': sharedPost,
      'shared_reel': sharedReel, // NEW
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'seen_at': seenAt?.toIso8601String(), // NEW
    };
  }
}

enum ChatStatusType { sent, seen, unread, normal, noMessages }

class ChatStatus {
  final ChatStatusType type;
  final String displayText;
  final Color textColor;
  final int? unreadCount;

  ChatStatus._({
    required this.type,
    required this.displayText,
    required this.textColor,
    this.unreadCount,
  });

  factory ChatStatus.sent(DateTime sentAt) => ChatStatus._(
    type: ChatStatusType.sent,
    displayText: 'Sent ${_formatTimeAgo(sentAt)}',
    textColor: Colors.grey[400]!,
  );

  factory ChatStatus.seen(DateTime seenAt) => ChatStatus._(
    type: ChatStatusType.seen,
    displayText: 'Seen ${_formatTimeAgo(seenAt)}',
    textColor: Colors.grey[400]!,
  );

  factory ChatStatus.unreadMessages(int count) => ChatStatus._(
    type: ChatStatusType.unread,
    displayText: count > 9 ? '9+ unread messages' : '$count unread message${count > 1 ? 's' : ''}',
    textColor: Colors.blue[300]!,
    unreadCount: count,
  );

  factory ChatStatus.normal(String? lastMessageContent) => ChatStatus._(
    type: ChatStatusType.normal,
    displayText: lastMessageContent ?? 'No messages yet',
    textColor: Colors.grey[400]!,
  );

  static String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}

// User Model for search results
class User {
  final String id;
  final String username;
  final String? profileImageUrl;
  final String? email;

  User({
    required this.id,
    required this.username,
    this.profileImageUrl,
    this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      email: json['email'] as String?,
    );
  }
}

// Minimal ChatRoom Model (can be expanded later if you have a chat_rooms table)
class ChatRoom {
  final String id;
  final String otherUserId;
  final String otherUsername;
  final String? otherUserProfileUrl;
  final Message? lastMessage;
  final int unreadCount; // NEW
  final ChatStatus status; // NEW
  final bool isAi;

  ChatRoom({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    this.otherUserProfileUrl,
    this.lastMessage,
    this.unreadCount = 0, // NEW
    required this.status, // NEW
    this.isAi = false,
  });
}