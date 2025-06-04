// Updated Reel model to include follow status
class Reel {
  final String id;
  final String videoUrl;
  final String userId;
  final String username;
  final String userAvatar;
  final String caption;
  final int likes;
  final int commentCount;
  final bool isLiked;
  final bool isFollowing; // Add this field
  final DateTime createdAt;
  final String? musicUrl;
  final double? musicTrimStart;
  final double? musicTrimEnd;
  final bool isVideoMuted;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.caption,
    required this.likes,
    required this.commentCount,
    required this.isLiked,
    this.isFollowing = false, // Default to false
    required this.createdAt,
    this.musicUrl,
    this.musicTrimStart,
    this.musicTrimEnd,
    this.isVideoMuted = false,
  });

  // Enhanced copyWith method
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
    bool? isFollowing,
    DateTime? createdAt,
    String? musicUrl,
    double? musicTrimStart,
    double? musicTrimEnd,
    bool? isVideoMuted,
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
      isFollowing: isFollowing ?? this.isFollowing,
      createdAt: createdAt ?? this.createdAt,
      musicUrl: musicUrl ?? this.musicUrl,
      musicTrimStart: musicTrimStart ?? this.musicTrimStart,
      musicTrimEnd: musicTrimEnd ?? this.musicTrimEnd,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoUrl': videoUrl,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'caption': caption,
      'likes': likes,
      'commentCount': commentCount,
      'isLiked': isLiked,
      'isFollowing': isFollowing,
      'createdAt': createdAt.toIso8601String(),
      'musicUrl': musicUrl,
      'musicTrimStart': musicTrimStart,
      'musicTrimEnd': musicTrimEnd,
      'isVideoMuted': isVideoMuted,
    };
  }

  // Create from JSON
  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'],
      videoUrl: json['videoUrl'],
      userId: json['userId'],
      username: json['username'],
      userAvatar: json['userAvatar'],
      caption: json['caption'],
      likes: json['likes'],
      commentCount: json['commentCount'],
      isLiked: json['isLiked'],
      isFollowing: json['isFollowing'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      musicUrl: json['musicUrl'],
      musicTrimStart: json['musicTrimStart'],
      musicTrimEnd: json['musicTrimEnd'],
      isVideoMuted: json['isVideoMuted'] ?? false,
    );
  }
}