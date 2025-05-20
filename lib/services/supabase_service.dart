import 'package:supabase_flutter/supabase_flutter.dart';

// Data models are included below the class definition
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

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

    // Step 2: Fetch posts made by followed users
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
        )
      ''')
        .inFilter('user_id', followedUserIds)
        .order('created_at', ascending: false);

    return (postsResponse as List).map((post) {
      final user = post['users'];
      return PostData(
        id: post['id'],
        userId: post['user_id'],
        username: user['username'],
        profileImageUrl: user['profile_image_url'],
        imageUrl: post['image_url'],
        caption: post['caption'],
        location: post['location'],
        createdAt: DateTime.parse(post['created_at']),
        likeCount: 0,
        // Fetch separately or join if needed
        commentCount: 0,
        // Fetch separately or join if needed
        isLiked: false,
      );
    }).toList();
  }

  // -------------------- STORY FEED --------------------
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

      // Get following stories
      List followingStories = [];
      if (ids.isNotEmpty) {
        followingStories = await _client
            .from('stories')
            .select('*, users:user_id (id, username, profile_image_url)')
            .inFilter('user_id', ids)
            .gte('expires_at', now.toIso8601String());
      }

      List<StoryData> allStories = [];

      // Add current user's story
      final userData = await getCurrentUser();
      if (myStories.isNotEmpty) {
        allStories.add(StoryData.fromJson({
          'id': myStories[0]['id'],
          'media_url': myStories[0]['media_url'],
          'user': myStories[0]['users'],
          'isMe': true,
          'hasStory': true,
          'isViewed': false,
        }));
      } else {
        allStories.add(StoryData.fromJson({
          'user': {
            'id': user.id,
            'username': userData?.username ?? 'Your Story',
            'profile_image_url': userData?.profileImageUrl,
          },
          'isMe': true,
          'hasStory': false,
          'isViewed': false,
        }));
      }

      // Add following stories
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
    });
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
    });
  }

  static Future<void> markStoryAsViewed(String storyId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('story_views').insert({
      'story_id': storyId,
      'viewer_id': user.id,
    });
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

  StoryData({
    this.id,
    required this.userId,
    required this.username,
    this.profileImageUrl,
    this.mediaUrl,
    required this.isMe,
    required this.hasStory,
    required this.isViewed,
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
    );
  }
}
