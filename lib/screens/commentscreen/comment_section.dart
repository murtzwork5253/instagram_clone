import 'package:Instagram/screens/auth/service/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';

// Function to show comment section as modal sheet
void showCommentSection(BuildContext context, String postId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (context) {
      return GestureDetector(
        onTap: () {}, // Prevents tap-through dismiss
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => CommentSection(
            postId: postId,
            scrollController: controller,
          ),
        ),
      );
    },
  );
}

class CommentSection extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;

  const CommentSection({
    Key? key,
    required this.postId,
    required this.scrollController,
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
  Map<String, List<String>> _commentLikes = {}; // Initialize with empty map
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
    _loadLikes(widget.postId);

    // Add listener to update button state when text changes
    _commentController.addListener(_updatePostButton);
  }

  void _loadLikes(String postId) async {
    try {
      final dataProvider =
          Provider.of<InstaDataProvider>(context, listen: false);
      final likes = await dataProvider.getCommentLikesMap(postId);
      if (mounted) {
        setState(() {
          _commentLikes = likes;
        });
      }
    } catch (e) {
      // Handle error gracefully
      if (mounted) {
        setState(() {
          _commentLikes = {};
        });
      }
    }
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
      final comments =
          await SupabaseService.getComments(widget.postId, forceRefresh: true);

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

      await Future.delayed(
          Duration(milliseconds: 200)); // Slight animation delay
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
                .from('avatars')
                .getPublicUrl(imageUrl)
            : null);

    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          duration: Duration(milliseconds: 250),
          padding: EdgeInsets.only(bottom: bottomInset),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: Container(
              // height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade800, width: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Comments',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Last refreshed indicator
                  if (_lastRefreshed != null)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      width: double.infinity,
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
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white))
                          : _comments.isEmpty
                              ? Center(
                                  child: ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      Container(
                                        height:
                                            MediaQuery.of(context).size.height /
                                                3,
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.chat_bubble_outline,
                                              size: 50,
                                              color: Colors.grey.shade600,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'No comments yet',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Start the conversation.',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  controller: widget.scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  itemCount: _comments.length,
                                  itemBuilder: (context, index) {
                                    final comment = _comments[index];
                                    if (currentUser == null) {
                                      return Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Text(
                                            'Please sign in to view comments.',
                                            style:
                                                TextStyle(color: Colors.grey),
                                          ),
                                        ),
                                      );
                                    }
                                    return AnimatedSwitcher(
                                      duration: Duration(milliseconds: 300),
                                      child: CommentTile(
                                        key: ValueKey(comment.id),
                                        // Needed for animation
                                        comment: comment,
                                        commentLikes: _commentLikes,
                                        currentUserId: currentUser.id,
                                        dataProvider: dataProvider,
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                  // Add comment section
                  Container(
                    padding: EdgeInsets.only(
                        left: 16, right: 16, top: 12, bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border(
                        top:
                            BorderSide(color: Colors.grey.shade800, width: 0.5),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          // Current user profile image
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: resolvedImageUrl != null
                                ? NetworkImage(resolvedImageUrl)
                                : null,
                            backgroundColor: Colors.grey.shade700,
                            child: resolvedImageUrl == null
                                ? Icon(Icons.person,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                          SizedBox(width: 12),
                          // Comment text field
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade800),
                              ),
                              child: TextField(
                                controller: _commentController,
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText:
                                      'Add a comment as ${currentUser?.username ?? "user"}...',
                                  border: InputBorder.none,
                                  hintStyle:
                                      TextStyle(color: Colors.grey.shade600),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) {
                                  if (_canPost) _addComment();
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Post button
                          GestureDetector(
                            onTap:
                                (_canPost && !_isPosting) ? _addComment : null,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              child: _isPosting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.blue),
                                      ),
                                    )
                                  : Icon(
                                      Icons.send,
                                      color: _canPost
                                          ? Colors.blue
                                          : Colors.grey.shade600,
                                      size: 24,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// Updated CommentTile widget with better styling
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
  bool _isExpanded = false;

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'just now';
  }

  ImageProvider? _getProfileImageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http')) {
      if (url.startsWith('public/')) {
        return NetworkImage(
          SupabaseService.client().storage.from('avatars').getPublicUrl(url),
        );
      }
      return null;
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final commentId = comment.id;
    final isLiked =
        widget.commentLikes[commentId]?.contains(widget.currentUserId) ?? false;
    final likeCount = widget.commentLikes[commentId]?.length ?? 0;

    final String contentPreview = comment.content.length > 120
        ? comment.content.substring(0, 120) + '...'
        : comment.content;

    final bool isTruncated = comment.content.length > 120;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: _getProfileImageProvider(comment.profileImageUrl),
            backgroundColor: Colors.grey.shade700,
            child: comment.profileImageUrl == null ||
                    comment.profileImageUrl!.isEmpty
                ? Icon(Icons.person, size: 18, color: Colors.white)
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
                        text: comment.username,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: ' ',
                        style: TextStyle(fontSize: 14),
                      ),
                      TextSpan(
                        text: _isExpanded || !isTruncated
                            ? comment.content
                            : contentPreview,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (isTruncated && !_isExpanded)
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = true),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'more',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ),
                  ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _getTimeAgo(comment.createdAt),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    SizedBox(width: 16),
                    if (likeCount > 0)
                      Text(
                        '$likeCount ${likeCount == 1 ? 'like' : 'likes'}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    SizedBox(width: 16),
                    InkWell(
                      onTap: () {
                        // TODO: Add reply action
                      },
                      child: Text(
                        'Reply',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final supabase = SupabaseService();
              final updated =
                  Set<String>.from(widget.commentLikes[commentId] ?? []);
              if (isLiked) {
                await supabase.unlikeComment(commentId, widget.currentUserId);
                updated.remove(widget.currentUserId);
              } else {
                await supabase.likeComment(commentId, widget.currentUserId);
                updated.add(widget.currentUserId);
              }
              setState(() {
                widget.commentLikes[commentId] = updated.toList();
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.grey.shade600,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
