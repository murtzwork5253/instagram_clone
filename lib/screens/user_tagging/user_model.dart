// models/tag_models.dart
class TaggedUser {
  final String id;
  final String username;
  final String? profileImageUrl;
  final String? bio;
  final String? fullName;

  TaggedUser({
    required this.id,
    required this.username,
    this.profileImageUrl,
    this.bio,
    this.fullName,
  });

  factory TaggedUser.fromJson(Map<String, dynamic> json) {
    return TaggedUser(
      id: json['id'] as String,
      username: json['username'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      bio: json['bio'] as String?,
      fullName: json['full_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'profile_image_url': profileImageUrl,
      'bio': bio,
      'full_name': fullName,
    };
  }

  TaggedUser copyWith({
    String? id,
    String? username,
    String? profileImageUrl,
    String? bio,
    String? fullName,
  }) {
    return TaggedUser(
      id: id ?? this.id,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      fullName: fullName ?? this.fullName,
    );
  }
}

class SearchableUser {
  final String id;
  final String username;
  final String? profileImageUrl;
  final String? fullName;
  final bool isFollowing;

  SearchableUser({
    required this.id,
    required this.username,
    this.profileImageUrl,
    this.fullName,
    this.isFollowing = false,
  });

  factory SearchableUser.fromJson(Map<String, dynamic> json) {
    return SearchableUser(
      id: json['id'] as String,
      username: json['username'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      fullName: json['full_name'] as String?,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }

  TaggedUser toTaggedUser({double? x, double? y}) {
    return TaggedUser(
      id: id,
      username: username,
      profileImageUrl: profileImageUrl,
    );
  }
}