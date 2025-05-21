import 'package:Instagram/screens/auth/service/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';

class CommentSection extends StatefulWidget {
  final String postId;

  const CommentSection({
    Key? key,
    required this.postId,
  }) : super(key: key);

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  bool _isLoading = false;
  bool _canPost = false;
  bool _isPosting = false;
  List<CommentData> _comments = [];
  DateTime? _lastRefreshed;
  final TextEditingController _commentController = TextEditingController();
  late Map<String, List<String>> _commentLikes;
  final String currentUserId = AuthService.client().auth.currentUser!.id;

  String _formatLastUpdated(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  void initState() {
    super.initState();
    // Add a slight delay to ensure the widget is fully mounted
    Future.delayed(Duration(milliseconds: 100), () {
      _loadComments();
    });
    _loadLikes(widget.postId); // Replace with actual postId

    // Add listener to update button state when text changes
    _commentController.addListener(_updatePostButton);
  }

  void _loadLikes(String postId) async {
    final dataProvider = Provider.of<InstaDataProvider>(context, listen: false);
    _commentLikes = await dataProvider.getCommentLikesMap(postId);
    setState(() {});
  }
  @override
  void dispose() {
    _commentController.removeListener(_updatePostButton);
    _commentController.dispose();
    super.dispose();
  }

  void _updatePostButton() {
    final canPost = _commentController.text.trim().isNotEmpty;
    if (canPost != _canPost) {
      setState(() {
        _canPost = canPost;
      });
    }
  }

  Future<void> _loadComments() async {
    // Only show loading indicator on initial load, not during refresh
    if (_comments.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Force refresh from database to get the latest comments
      final comments = await SupabaseService.getComments(widget.postId, forceRefresh: true);

      if (mounted) {
        setState(() {
          _comments = comments;
          _lastRefreshed = DateTime.now();
        });
      }
    } catch (e) {
      // Only show error if not in a refresh
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load comments: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addComment() async {
    if (!_canPost || _isPosting) return;

    final content = _commentController.text.trim();
    final provider = Provider.of<InstaDataProvider>(context, listen: false);

    setState(() {
      _isPosting = true;
    });

    try {
      await provider.addComment(widget.postId, content);
      _commentController.clear();
      // This will trigger _updatePostButton via the listener

      // Refresh comments
      _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<InstaDataProvider>(context).currentUser;
    final String? imageUrl = currentUser?.profileImageUrl;
    final bool isPublicUrl = imageUrl != null && imageUrl.startsWith('http');
    final dataProvider = Provider.of<InstaDataProvider>(context);

    final String? resolvedImageUrl = isPublicUrl
        ? imageUrl
        : (imageUrl != null
        ? Supabase.instance.client.storage
        .from('avatars') // Adjust if your bucket name is different
        .getPublicUrl(imageUrl)
        : null);


    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Comments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Last refreshed indicator
          if (_lastRefreshed != null)
            Container(
              padding: EdgeInsets.symmetric(vertical: 4),
              width: double.infinity,
              color: Colors.black,
              alignment: Alignment.center,
              child: Text(
                'Last updated ${_formatLastUpdated(_lastRefreshed!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          // Comments list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadComments,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? Center(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height / 2,
                      alignment: Alignment.center,
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  if (currentUser == null) {
                    return Center(child: Text('Please sign in to view comments.'));
                  }
                  return CommentTile(
                    comment: comment,
                    commentLikes: _commentLikes,
                    currentUserId: currentUser.id,
                    dataProvider: dataProvider,
                  );
                },
              ),
            ),
          ),
          // Add comment section
          Container(
            padding: EdgeInsets.only(left: 8.0, bottom: 16.0,right: 8,top: 10),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                // Current user profile image
                CircleAvatar(
                  radius: 18,
                  backgroundImage: resolvedImageUrl != null
                      ? NetworkImage(resolvedImageUrl)
                      : null,
                  backgroundColor: Colors.grey.shade300,
                  child: resolvedImageUrl == null
                      ? Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 10),
                // Comment text field
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment as ${currentUser?.username ?? "user"}...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (_canPost) _addComment();
                    },
                  ),
                ),
                // Post button
                TextButton(
                  onPressed: (_canPost && !_isPosting) ? _addComment : null,
                  child: _isPosting
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                      : Text(
                    'Post',
                    style: TextStyle(
                      color: _canPost
                          ? Colors.blue
                          : Colors.blue.shade200,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Updated CommentTile widget with fixed image URL handling
class CommentTile extends StatefulWidget {
  final CommentData comment;
  final Map<String, List<String>> commentLikes;
  final String currentUserId;
  final InstaDataProvider dataProvider;

  const CommentTile({
    Key? key,
    required this.comment,
    required this.commentLikes,
    required this.currentUserId,
    required this.dataProvider,
  }) : super(key: key);

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'just now';
    }
  }

  ImageProvider? _getProfileImageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.startsWith('public/')) {
        final storageUrl = SupabaseService.client().storage.from('avatars').getPublicUrl(url);
        return NetworkImage(storageUrl);
      }
      return null;
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final commentId = widget.comment.id;
    final isLiked = widget.commentLikes[commentId]?.contains(widget.currentUserId) ?? false;
    final likeCount = widget.commentLikes[commentId]?.length ?? 0;
    final supabaseService = SupabaseService();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: _getProfileImageProvider(widget.comment.profileImageUrl),
            backgroundColor: Colors.grey.shade300,
            child: widget.comment.profileImageUrl == null || widget.comment.profileImageUrl!.isEmpty
                ? Icon(Icons.person, color: Colors.white, size: 18)
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: widget.comment.username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' ${widget.comment.content}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _getTimeAgo(widget.comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Reply',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.grey,
                  size: 20,
                ),
                onPressed: () async {
                  if (isLiked) {
                    await supabaseService.unlikeComment(commentId, widget.currentUserId);
                    setState(() {
                      widget.commentLikes[commentId]?.remove(widget.currentUserId);
                    });
                  } else {
                    await supabaseService.likeComment(commentId, widget.currentUserId);
                    setState(() {
                      widget.commentLikes.putIfAbsent(commentId, () => []).add(widget.currentUserId);
                    });
                  }
                },
              ),
              Text('$likeCount'),
            ],
          ),
        ],
      ),
    );
  }
}
