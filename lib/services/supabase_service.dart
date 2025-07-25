import 'dart:ffi';

import 'package:Instagram/services/push_notification_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart'; // Assuming you use uuid for unique file names
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'dart:io';
import '../screens/notificationscreen/service/notification_service.dart';
import 'blocked_users_service.dart';

// Data models are included below the class definition
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final Uuid _uuid = Uuid();

  static SupabaseClient client() => _client;

  // -------------------- AUTH --------------------
  static Future<UserData?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final userData =
            await _client.from('users').select().eq('id', user.id).single();
        return UserData.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // -------------------- USER SEARCH --------------------
  static Future<List<UserData>> searchUsers(String query) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return [];
      // Fetch blocked users
      final blockedService = BlockedUsersService();
      final blockedUsers = await blockedService.getBlockedUsers();
      final blockedIds = blockedUsers.map((u) => u['id']).toSet();

      final response = await _client
          .from('users')
          .select()
          .ilike('username', '%$query%')
          .order('username')
          .limit(20);

      return (response as List)
          .where((e) => !blockedIds.contains(e['id']))
          .map((e) => UserData.fromJson(e))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // -------------------- POST FEED --------------------
  static Future<List<PostData>> getFeedPosts() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    // Step 1: Fetch IDs of followed users
    final followingResponse = await Supabase.instance.client
        .from('followers')
        .select('following_id')
        .eq('follower_id', userId);

    final followedUserIds = (followingResponse as List)
        .map((row) => row['following_id'] as String)
        .toList();

    // Always include own ID
    followedUserIds.add(userId);

    // Fetch blocked users
    final blockedService = BlockedUsersService();
    final blockedUsers = await blockedService.getBlockedUsers();
    final blockedIds = blockedUsers.map((u) => u['id']).toSet();

    // Step 2: Fetch posts and join related data
    final postsResponse = await Supabase.instance.client
        .from('posts')
        .select('''
        id,
        user_id,
        caption,
        location,
        image_url,
        created_at,
        disable_comments,
        use_original_ratio,
        image_transformation,
        original_aspect_ratio,
        users (
          username,
          profile_image_url
        ),
        post_likes (
          user_id
        ),
        comments (
          id
        )
      ''')
        .inFilter('user_id', followedUserIds)
        .order('created_at', ascending: false);

    return (postsResponse as List)
        .where((post) => !blockedIds.contains(post['user_id']))
        .map((post) {
      final user = post['users'];
      final likes = post['post_likes'] as List<dynamic>? ?? [];
      final comments = post['comments'] as List<dynamic>? ?? [];

      final isLiked = likes.any((like) => like['user_id'] == userId);

      return PostData(
        id: post['id'],
        userId: post['user_id'],
        username: user['username'],
        profileImageUrl: user['profile_image_url'],
        imageUrl: post['image_url'],
        caption: post['caption'],
        location: post['location'],
        createdAt: DateTime.parse(post['created_at']),
        likeCount: likes.length,
        commentCount: comments.length,
        isLiked: isLiked,
        disableComments: post['disable_comments'] ?? false,
        use_original_ratio: post['use_original_ratio'],
        image_transformation: post['image_transformation'],
        original_aspect_ratio: (post['original_aspect_ratio'] as num?)?.toDouble() ?? 1.0,
      );
    }).toList();
  }

  // -------------------- STORY FEED --------------------
  // Inside lib/services/supabase_service.dart

  static Future<List<StoryData>> getStories() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final now = DateTime.now().toUtc();

      // Get my stories
      final myStories = await _client
          .from('stories')
          .select('*, users:user_id (id, username, profile_image_url)') // Select shared_post_id
          .eq('user_id', user.id)
          .gte('expires_at', now.toIso8601String());


      // Get following ids
      final followingIds = await _client
          .from('followers')
          .select('following_id')
          .eq('follower_id', user.id);

      List<String> ids = [];
      if (followingIds.isNotEmpty) {
        ids = (followingIds as List)
            .map((e) => e['following_id'] as String)
            .toList();
      }

      // Get all stories from followed users
      List<dynamic> followingStories = [];
      if (ids.isNotEmpty) {
        followingStories = await _client
            .from('stories')
            .select('*, users:user_id (id, username, profile_image_url)') // Select shared_post_id
            .inFilter('user_id', ids)
            .gte('expires_at', now.toIso8601String());
      }

      final List<StoryData> allStories = [];

      // Process My Stories
      if (myStories.isNotEmpty) {
        for (final story in myStories) {
          final viewed = await _client
              .from('story_views')
              .select()
              .eq('story_id', story['id'])
              .eq('viewer_id', user.id)
              .maybeSingle();

          allStories.add(StoryData.fromJson({
            ...story,
            'user': story['users'],
            'isMe': true,
            'hasStory': true,
            'isViewed': viewed != null,
          }));
        }
      }

      // Following stories
      for (final story in followingStories) {
        try {
          final viewed = await _client
              .from('story_views')
              .select()
              .eq('story_id', story['id'])
              .eq('viewer_id', user.id)
              .maybeSingle();

          allStories.add(StoryData.fromJson({
            ...story,
            'user': story['users'],
            'isMe': false,
            'hasStory': true,
            'isViewed': viewed != null,
          }));
        } catch (e) {
          print('Error processing story ${story['id']}: $e');
          continue;
        }
      }

      return allStories;
    } catch (e) {
      print('Error getting stories: $e');
      return [];
    }
  }

  /// Send a follow notification
  static Future<void> sendFollowNotification({
    required String userToFollowId,
  }) async {
    await NotificationService().createNotification(
      recipientId: userToFollowId,
      type: 'follow', senderId: _client.auth.currentUser!.id,
    );
  }

  // -------------------- FOLLOWING --------------------
  static Future<bool> toggleFollow(String userId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null || user.id == userId) throw Exception('Invalid action');

      final follow = await _client
          .from('followers')
          .select()
          .eq('follower_id', user.id)
          .eq('following_id', userId)
          .maybeSingle();

      if (follow != null) {
        await _client.from('followers').delete().eq('id', follow['id']);
        return false;
      } else {
        await _client.from('followers').insert({
          'follower_id': user.id,
          'following_id': userId,
        });
        await sendFollowNotification(userToFollowId: userId);
        return true;
      }
    } catch (e) {
      print('Error toggling follow: $e');
      rethrow;
    }
  }

  static Future<void> createPost({
    required String imageUrl,
    required String caption,
    String? location,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('posts').insert({
      'user_id': user.id,
      'image_url': imageUrl,
      'caption': caption,
      'location': location,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<bool> deletePost(String postId, String mediaPath) async {
    try {
      final client = SupabaseService.client();

      // Step 1: Delete post likes
      await client
          .from('post_likes')
          .delete()
          .eq('post_id', postId);

      // Step 2: Fetch all comment IDs related to this post
      final commentResponse = await client
          .from('comments')
          .select('id')
          .eq('post_id', postId);

      final commentIds = List<String>.from(commentResponse.map((e) => e['id']));

      // Step 3: Delete comment likes
      if (commentIds.isNotEmpty) {
        await client
            .from('comment_likes')
            .delete()
            .inFilter('comment_id', commentIds);
      }

      // Step 4: Delete comments
      await client
          .from('comments')
          .delete()
          .eq('post_id', postId);

      // Step 5: Delete the post
      await client
          .from('posts')
          .delete()
          .eq('id', postId)
          .select();

      // Step 6: Delete media file from storage
      await client.storage
          .from('post-media')
          .remove([mediaPath]);

      return true;
    } catch (e) {
      print('Error deleting post and related data: $e');
      return false;
    }
  }


  String extractMediaPath(String imageUrl) {
    final uri = Uri.parse(imageUrl);
    final segments = uri.pathSegments;

    final postMediaIndex = segments.indexOf('post-media');
    if (postMediaIndex != -1 && postMediaIndex + 1 < segments.length) {
      return segments.sublist(postMediaIndex + 1).join('/');
    }

    throw FormatException('Invalid Supabase image URL format');
  }

  static Future<void> sendLikeNotification({
    required String postOwnerId,
    required String postId,
  }) async {
    await NotificationService().createNotification(
      recipientId: postOwnerId,
      type: 'like',
      postId: postId, senderId: _client.auth.currentUser!.id,
    );
  }

  static Future<bool> toggleLike(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final existing = await _client
        .from('post_likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      await _client.from('post_likes').delete().eq('id', existing['id']);
      await sendLikeNotification(
        postOwnerId: user.id,
        postId: postId,
      );
      return false;
    } else {
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': user.id,
      });
      return true;
    }
  }

  // Send a comment notification
  static Future<void> sendCommentNotification({
    required String postOwnerId,
    required String postId,
  }) async {
    await NotificationService().createNotification(
      recipientId: postOwnerId,
      type: 'comment',
      postId: postId,
      senderId: _client.auth.currentUser!.id,
    );
  }
  static Future<void> addComment(String postId, String content) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'content': content,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    await sendCommentNotification(
      postOwnerId: user.id,
      postId: postId,
    );
  }

  // Update the getComments method in supabase_service.dart
  static Future<List<CommentData>> getComments(String postId, {bool forceRefresh = false}) async {
    try {
      // Get all comments for the post without filtering by user relationship
      // This ensures all comments are visible regardless of who posted them
      final result = await _client
          .from('comments')
          .select('id, content, created_at, user_id, users:user_id(username, profile_image_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: false);


      return (result as List).map((comment) {
        final user = comment['users'] as Map<String, dynamic>?;

        return CommentData(
          id: comment['id'],
          userId: comment['user_id'],
          username: user?['username'] ?? 'Unknown User',
          profileImageUrl: user?['profile_image_url'],
          content: comment['content'],
          createdAt: DateTime.parse(comment['created_at']),
        );
      }).toList();
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createStory(String mediaUrl, {String? sharedPostId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final now = DateTime.now().toUtc();
    final expiresAt = now.add(Duration(hours: 24));

    final response = await _client.from('stories').insert({
      'user_id': user.id,
      'media_url': mediaUrl,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': now.toIso8601String(),
      'shared_post_id': sharedPostId, // Insert the shared post ID
    }).select().single();

    return response;
  }

  // New method to fetch a single post by its ID
  static Future<PostData?> getPostById(String postId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await Supabase.instance.client
          .from('posts')
          .select('''
                id, user_id, caption, location, image_url, created_at, disable_comments,
                use_original_ratio, image_transformation, original_aspect_ratio,
                users (username, profile_image_url),
                post_likes (user_id),
                comments (id)
            ''')
          .eq('id', postId)
          .single();

      final post = response;
      final user = post['users'];
      final likes = post['post_likes'] as List<dynamic>? ?? [];
      final comments = post['comments'] as List<dynamic>? ?? [];
      final isLiked = likes.any((like) => like['user_id'] == userId);

      // Check for saved status
      final savedResponse = await Supabase.instance.client
          .from('saved_posts')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return PostData(
        id: post['id'],
        userId: post['user_id'],
        username: user['username'],
        profileImageUrl: user['profile_image_url'],
        imageUrl: post['image_url'],
        caption: post['caption'],
        location: post['location'],
        createdAt: DateTime.parse(post['created_at']),
        likeCount: likes.length,
        commentCount: comments.length,
        isLiked: isLiked,
        isSaved: savedResponse != null,
        disableComments: post['disable_comments'] ?? false,
        use_original_ratio: post['use_original_ratio'],
        image_transformation: post['image_transformation'],
        original_aspect_ratio: (post['original_aspect_ratio'] as num?)?.toDouble() ?? 1.0,
      );
    } catch (e) {
      print("Error fetching post by ID: $e");
      return null;
    }
  }

  // Inside lib/services/supabase_service.dart

  static Future<void> markStoryAsViewed(String storyId,{required String storyOwnerId}) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        print('User not authenticated to mark story as viewed.');
        return;
      }
      print('Marking story $storyId as viewed by $currentUserId.');

      // The condition to skip view tracking for own stories has been removed.
      // Now, even if currentUserId == storyOwnerId, the upsert will proceed.

      // Use upsert to prevent duplicate key violations
      // 'story_id,viewer_id' should match the columns that form your unique constraint
      await _client.from('story_views').upsert(
        {
          'story_id': storyId,
          'viewer_id': currentUserId,
          'viewed_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'story_id,viewer_id', // Specify the unique constraint columns
      );
      print('Story $storyId marked as viewed by $currentUserId (upserted).');
    }on PostgrestException catch (e) {
      print('Supabase PostgrestException: ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected error: $e');
      rethrow;
    }
  }

  Future<void> likeComment(String commentId, String userId) async {
    await _client.from('comment_likes').insert({
      'comment_id': commentId,
      'user_id': userId,
    });
  }

  Future<void> unlikeComment(String commentId, String userId) async {
    await _client
        .from('comment_likes')
        .delete()
        .eq('comment_id', commentId)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> getCommentLikes(String postId) async {
    final response = await _client
        .from('comment_likes')
        .select('comment_id, user_id')
        .inFilter('comment_id',
        (await _client.from('comments')
            .select('id')
            .eq('post_id', postId)
        ).map((e) => e['id'] as String).toList()
    );

    return response;
  }

  static Future<String> uploadStoryMedia(
      File mediaFile, {
        void Function(double progress)? onProgress,
      }) async {
    const String folder = 'story-media';
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final fileExt = path.extension(mediaFile.path).toLowerCase();
    final fileName = '${_uuid.v4()}$fileExt';
    final filePath = '${user.id}/$fileName';

    Uint8List bytesToUpload;

    if (fileExt == '.jpg' || fileExt == '.jpeg' || fileExt == '.png') {
      // 🗜️ Compress image before upload
      final compressed = await FlutterImageCompress.compressWithFile(
        mediaFile.path,
        minWidth: 1080,
        minHeight: 1080,
        quality: 70,
        format: fileExt == '.png' ? CompressFormat.png : CompressFormat.jpeg,
      );

      if (compressed == null) throw Exception('Image compression failed');
      bytesToUpload = Uint8List.fromList(compressed);

      // Fake simple progress
      onProgress?.call(0.5);
    } else {
      // 📄 For non-image media (e.g., video), stream as-is
      final total = await mediaFile.length();
      final bytes = <int>[];
      int sent = 0;

      await for (final chunk in mediaFile.openRead()) {
        bytes.addAll(chunk);
        sent += chunk.length;
        onProgress?.call(sent / total);
      }

      bytesToUpload = Uint8List.fromList(bytes);
    }

    // 📤 Upload to Supabase
    await _client.storage.from(folder).uploadBinary(
      filePath,
      bytesToUpload,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );

    onProgress?.call(1.0);

    return _client.storage.from(folder).getPublicUrl(filePath);
  }

  Future<void> deleteStory(String storyId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Delete the story (and optionally, its media from storage if needed)
    await _client.from('stories').delete().eq('id', storyId);
    // Optionally, delete associated story views, etc.
  }

}

class UserData {
  final String id;
  final String username;
  final String? profileImageUrl;
  final String? email;
  final String? bio;

  UserData({
    required this.id,
    required this.username,
    this.profileImageUrl,
    this.email,
    this.bio,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
        id: json['id'],
        username: json['username'],
        profileImageUrl: json['profile_image_url'],
        email: json['email'],
        bio: json['bio'],
      );
}

class PostData {
  @override
  String toString() {
    return 'PostData(username: $username, profileImageUrl: $profileImageUrl, imageUrl: $imageUrl, likeCount: $likeCount, commentCount: $commentCount, isLiked: $isLiked)';
  }

  final String id;
  final String userId;
  final String username;
  final String? profileImageUrl;
  final String imageUrl;
  final String? caption;
  final String? location;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isSaved;
  final bool disableComments;
  final bool? use_original_ratio;
  final String? image_transformation;
  final double? original_aspect_ratio;

  PostData({
    required this.id,
    required this.userId,
    required this.username,
    this.profileImageUrl,
    required this.imageUrl,
    this.caption,
    this.location,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    this.isSaved = false,
    this.disableComments = false,
    this.use_original_ratio,
    this.image_transformation,
    this.original_aspect_ratio,
  });

  factory PostData.fromJson(Map<String, dynamic> json,
      {required int likeCount,
      required int commentCount,
      required bool isLiked}) {
    final user = json['users'] ?? {};
    return PostData(
      id: json['id'],
      userId: json['user_id'],
      username: user['username'] ?? '',
      profileImageUrl: user['profile_image_url'],
      imageUrl: json['image_url'],
      caption: json['caption'],
      location: json['location'],
      createdAt: DateTime.parse(json['created_at']),
      likeCount: likeCount,
      commentCount: commentCount,
      isLiked: isLiked,
      isSaved: false,
      disableComments: json['disable_comments'] ?? false,
      use_original_ratio: json['use_original_ratio'],
      image_transformation: json['image_transformation'],
      original_aspect_ratio: (json['original_aspect_ratio'] as num?)?.toDouble(),
    );
  }



}

class StoryData {
  final String? id;
  final String userId;
  final String username;
  final String? profileImageUrl;
  final String? mediaUrl;
  final bool isMe;
  final bool hasStory;
  final bool isViewed;
  final DateTime? createdAt;
  final String? sharedPostId;

  StoryData({
    this.id,
    required this.userId,
    required this.username,
    this.profileImageUrl,
    this.mediaUrl,
    required this.isMe,
    required this.hasStory,
    required this.isViewed,
    this.createdAt,
    this.sharedPostId,
  });

  factory StoryData.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? {};
    return StoryData(
      id: json['id'],
      userId: user['id'] ?? '',
      username: user['username'] ?? '',
      profileImageUrl: user['profile_image_url'],
      mediaUrl: json['media_url'],
      isMe: json['isMe'] ?? false,
      hasStory: json['hasStory'] ?? false,
      isViewed: json['isViewed'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      sharedPostId: json['shared_post_id'],
    );
  }
}

class CommentData {
  final String id;
  final String userId;
  final String username;
  final String? profileImageUrl;
  final String content;
  final DateTime createdAt;

  CommentData({
    required this.id,
    required this.userId,
    required this.username,
    this.profileImageUrl,
    required this.content,
    required this.createdAt,
  });

  factory CommentData.fromJson(Map<String, dynamic> json) {
    final user = json['users'] ?? {};

    return CommentData(
      id: json['id'],
      userId: json['user_id'],
      username: user['username'] ?? 'Anonymous',
      profileImageUrl: user['profile_image_url'],
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
