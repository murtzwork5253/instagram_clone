import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/blocked_users_service.dart';

// Data model for a single story item
class StoryItem {
  final String id;
  final String mediaUrl;
  final DateTime createdAt;
  bool isViewed;

  StoryItem({
    required this.id,
    required this.mediaUrl,
    required this.createdAt,
    this.isViewed = false,
  });
}

// Data model to group stories by user
class UserStoryBundle {
  final String userId;
  final String username;
  final String? profileImageUrl;
  final List<StoryItem> stories;
  final bool isMe;

  UserStoryBundle({
    required this.userId,
    required this.username,
    required this.profileImageUrl,
    required this.stories,
    required this.isMe,
  });

  // A helper to check if all stories in the bundle have been viewed
  bool get allStoriesViewed => stories.every((story) => story.isViewed);
}

class StoryProvider extends ChangeNotifier {
  List<UserStoryBundle> _stories = [];
  bool _isLoading = false;
  String? _error;

  List<UserStoryBundle> get stories => _stories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StoryProvider() {
    fetchStories();
  }

  Future<void> fetchStories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      if (currentUserId == null) {
        _stories = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await supabase
          .from('stories')
          .select('*, user:users(username, profile_image_url), story_views(viewer_id)')
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      final blockedService = BlockedUsersService();
      final blockedUsers = await blockedService.getBlockedUsers();
      final blockedIds = blockedUsers.map((u) => u['id']).toSet();

      final Map<String, UserStoryBundle> storyBundles = {};

      for (final record in response) {
        final storyUserId = record['user_id'];
        if (storyUserId == null) continue;
        if (blockedIds.contains(storyUserId)) continue;

        final user = record['user'];
        if (user == null) continue;

        final storyId = record['id'];
        final viewedBy = (record['story_views'] as List)
            .map((view) => view['viewer_id'])
            .toList();

        final storyItem = StoryItem(
          id: storyId,
          mediaUrl: 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/story-media/${record['media_url']}',
          createdAt: DateTime.parse(record['created_at']),
          isViewed: viewedBy.contains(currentUserId),
        );

        if (storyBundles.containsKey(storyUserId)) {
          storyBundles[storyUserId]!.stories.add(storyItem);
        } else {
          storyBundles[storyUserId] = UserStoryBundle(
            userId: storyUserId,
            username: user['username'] ?? 'Unknown',
            profileImageUrl: user['profile_image_url'],
            stories: [storyItem],
            isMe: storyUserId == currentUserId,
          );
        }
      }

      if (!storyBundles.containsKey(currentUserId)) {
        final currentUserResponse = await supabase
            .from('users')
            .select('username, profile_image_url')
            .eq('id', currentUserId)
            .single();

        storyBundles[currentUserId] = UserStoryBundle(
            userId: currentUserId,
            username: currentUserResponse['username'] ?? 'You',
            profileImageUrl: currentUserResponse['profile_image_url'],
            stories: [],
            isMe: true);
      }

      final sortedList = storyBundles.values.toList()
        ..sort((a, b) {
          if (a.isMe) return -1;
          if (b.isMe) return 1;
          return 0;
        });

      _stories = sortedList;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}