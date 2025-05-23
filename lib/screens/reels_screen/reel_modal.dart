class Reel {
  final String id;
  final String videoUrl;
  final String userId;
  final String username;
  final String userAvatar;
  final String caption;
  final int likes;
  final DateTime createdAt;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.caption,
    required this.likes,
    required this.createdAt,
  });

  factory Reel.fromMap(Map<String, dynamic> map) {
    return Reel(
      id: map['id'],
      videoUrl: map['video_url'],
      userId: map['user_id'],
      username: map['username'],
      userAvatar: map['user_avatar'],
      caption: map['caption'],
      likes: map['likes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
