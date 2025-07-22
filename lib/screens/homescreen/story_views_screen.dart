import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryViewsScreen extends StatefulWidget {
  final String storyId;

  const StoryViewsScreen({Key? key, required this.storyId}) : super(key: key);

  @override
  State<StoryViewsScreen> createState() => _StoryViewsScreenState();
}

class _StoryViewsScreenState extends State<StoryViewsScreen> {
  List<StoryViewer> viewers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoryViewers();
  }

  Future<void> _loadStoryViewers() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        print('No current user ID found');
        setState(() => isLoading = false);
        return;
      }

      print('Current user ID: $currentUserId');
      print('Story ID: ${widget.storyId}');

      // Use RPC function or direct query with proper RLS
      final response = await Supabase.instance.client
          .rpc('get_story_viewers', params: {
        'story_id_param': widget.storyId,
        'current_user_id': currentUserId,
      });

      print('Story viewers response: $response');

      final viewersList = <StoryViewer>[];
      for (final item in response) {
        viewersList.add(StoryViewer(
          viewerId: item['viewer_id'],
          username: item['username'] ?? 'Unknown',
          profileImageUrl: item['profile_image_url'],
          viewedAt: DateTime.parse(item['viewed_at']),
        ));
      }

      setState(() {
        viewers = viewersList;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading story viewers: $e');
      setState(() => isLoading = false);
    }
  }

  String? _buildProfileImageUrl(String? url) {
    const supabasePublicBase =
        'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/';
    if (url == null || url.isEmpty) return null;
    if (Uri.tryParse(url)?.hasAbsolutePath ?? false) return url;
    return '$supabasePublicBase$url';
  }

  String _formatViewTime(DateTime viewedAt) {
    final difference = DateTime.now().difference(viewedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context), // This will return to story view
        ),
        title: Text(
          '${viewers.length} views',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: false,
      ),
      body: WillPopScope( // Handle Android back button
        onWillPop: () async {
          Navigator.pop(context);
          return false;
        },
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : viewers.isEmpty
            ? const Center(
          child: Text(
            'No views yet',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        )
            : ListView.builder(
          itemCount: viewers.length,
          itemBuilder: (context, index) {
            final viewer = viewers[index];
            return ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: viewer.profileImageUrl != null
                    ? CachedNetworkImageProvider(
                    _buildProfileImageUrl(viewer.profileImageUrl)!)
                    : null,
                child: viewer.profileImageUrl == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              title: Text(
                viewer.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // trailing: Text(
              //   _formatViewTime(viewer.viewedAt),
              //   style: const TextStyle(
              //     color: Colors.grey,
              //     fontSize: 12,
              //   ),
              // ),
            );
          },
        ),
      ),
    );
  }
}

class StoryViewer {
  final String viewerId;
  final String username;
  final String? profileImageUrl;
  final DateTime viewedAt;

  StoryViewer({
    required this.viewerId,
    required this.username,
    this.profileImageUrl,
    required this.viewedAt,
  });
}