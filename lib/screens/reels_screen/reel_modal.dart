class Reel {
  final String id;
  final String videoUrl;
  final String userId;
  final String username;
  final String userAvatar;
  final String caption;
  final int likes;
  final int commentCount; // Added for comment display
  final bool isLiked; // Added for current user's like status
  final DateTime createdAt;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.caption,
    required this.likes,
    this.commentCount = 0, // Default value
    this.isLiked = false, // Default value
    required this.createdAt,
  });

  factory Reel.fromMap(Map<String, dynamic> map) {
    // You'll need to fetch 'isLiked' and 'commentCount' from your database
    // This example assumes they are present or defaults to false/0 if not
    return Reel(
      id: map['id'],
      videoUrl: map['video_url'],
      userId: map['user_id'],
      username: map['username'],
      userAvatar: map['user_avatar'],
      caption: map['caption'],
      likes: map['likes'] ?? 0, // Ensure int
      commentCount: map['comment_count'] ?? 0, // Fetch from DB or default
      isLiked: map['is_liked'] ?? false, // Fetch from DB or default
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Add copyWith method for immutability
  Reel copyWith({
    String? id,
    String? videoUrl,
    String? userId,
    String? username,
    String? userAvatar,
    String? caption,
    int? likes,
    int? commentCount,
    bool? isLiked,
    DateTime? createdAt,
  }) {
    return Reel(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      caption: caption ?? this.caption,
      likes: likes ?? this.likes,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}