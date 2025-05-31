import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart'; // Assuming you use uuid for unique file names
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'dart:io';

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
      final response = await _client
          .from('users')
          .select()
          .ilike('username', '%$query%')
          .order('username')
          .limit(20);

      return (response as List).map((e) => UserData.fromJson(e)).toList();
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

    return (postsResponse as List).map((post) {
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
          .select('*, users:user_id (id, username, profile_image_url)')
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
            .select('*, users:user_id (id, username, profile_image_url)')
            .inFilter('user_id', ids)
            .gte('expires_at', now.toIso8601String());
      }

      final List<StoryData> allStories = [];

      // Process My Stories
      // final userData = await getCurrentUser();
      // Process My Stories
      if (myStories.isNotEmpty) {
        for (final story in myStories) {
          final viewed = await _client
              .from('story_views')
              .select()
              .eq('story_id', story['id'])
              .eq('viewer_id', user.id)
              .maybeSingle();

          print('SupabaseService - Story ID: ${story['id']}, isViewed: ${viewed != null}');

          allStories.add(StoryData.fromJson({
            ...story,
            'user': story['users'],
            'isMe': true,
            'hasStory': true,
            'isViewed': viewed != null,
          }));
        }
        myStories.map((s) => {'id': s['id'], 'is_viewed': s['isViewed']}).toList();
        print('My Stories: $myStories');
      }

      // Following stories (this part was already correct)
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
      return false;
    } else {
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': user.id,
      });
      return true;
    }
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

  static Future<void> createStory(String mediaUrl) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final now = DateTime.now().toUtc();
    final expiresAt = now.add(Duration(hours: 24));

    await _client.from('stories').insert({
      'user_id': user.id,
      'media_url': mediaUrl,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': now.toIso8601String(),
    });
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

}

class UserData {
  final String id;
  final String username;
  final String? profileImageUrl;

  UserData({
    required this.id,
    required this.username,
    this.profileImageUrl,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
        id: json['id'],
        username: json['username'],
        profileImageUrl: json['profile_image_url'],
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
