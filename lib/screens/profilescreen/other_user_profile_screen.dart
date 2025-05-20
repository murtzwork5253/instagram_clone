import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;

  const OtherUserProfileScreen({required this.userId, Key? key})
      : super(key: key);

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? profile;
  List<dynamic> posts = [];
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadOtherProfile();
  }

  Future<void> _loadOtherProfile() async {
    final profileRes =
        await supabase.from('users').select().eq('id', widget.userId).single();

    final postRes =
        await supabase.from('posts').select().eq('user_id', widget.userId);

    final followRes = await supabase.from('followers').select().match({
      'follower_id': supabase.auth.currentUser!.id,
      'following_id': widget.userId
    });

    setState(() {
      profile = profileRes;
      posts = postRes;
      isFollowing = followRes.isNotEmpty;
    });
  }

  Future<void> _toggleFollow() async {
    final currentUserId = supabase.auth.currentUser!.id;
    if (isFollowing) {
      await supabase
          .from('followers')
          .delete()
          .match({'follower_id': currentUserId, 'following_id': widget.userId});
    } else {
      await supabase.from('followers').insert({
        'follower_id': currentUserId,
        'following_id': widget.userId,
      });
    }
    setState(() {
      isFollowing = !isFollowing;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body:
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final rawAvatar = profile!['profile_image_url'];
    final avatarUrl = rawAvatar != null
        ? (rawAvatar.toString().startsWith('http')
            ? rawAvatar
            : supabase.storage.from('avatars').getPublicUrl(rawAvatar))
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(profile!['username'],
            style: const TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Avatar, name, bio...
            CircleAvatar(
              radius: 48,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              backgroundColor: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(profile!['full_name'],
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 4),
            Text(profile!['bio'] ?? '',
                style: const TextStyle(color: Colors.white70)),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _toggleFollow,
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
              child: Text(isFollowing ? 'Unfollow' : 'Follow'),
            ),

            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final mediaPath = posts[index]['image_url'];
                final mediaUrl = mediaPath.toString().startsWith('http')
                    ? mediaPath
                    : supabase.storage
                        .from('post-media')
                        .getPublicUrl(mediaPath);

                return Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                        image: NetworkImage(mediaUrl), fit: BoxFit.cover),
                    color: Colors.grey,
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
