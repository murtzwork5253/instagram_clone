import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
// Assuming you have a SupabaseService

// --- Data Models ---
// Message Model
class Message {
  final String id;
  final String? senderId;
  final String? receiverId;
  final String? content;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? seenAt; // NEW FIELD

  Message({
    required this.id,
    this.senderId,
    this.receiverId,
    this.content,
    this.imageUrl,
    required this.isRead,
    required this.createdAt,
    this.seenAt, // NEW FIELD
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      senderId: json['sender_id'] as String?,
      receiverId: json['receiver_id'] as String?,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      seenAt: json['seen_at'] != null ? DateTime.parse(json['seen_at'] as String).toLocal() : null, // NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'image_url': imageUrl,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'seen_at': seenAt?.toIso8601String(), // NEW
    };
  }
}

// ADD THIS NEW CODE
enum ChatStatusType { sent, seen, unread, normal, noMessages }

class ChatStatus {
  final ChatStatusType type;
  final String displayText;
  final Color textColor;
  final int? unreadCount;

  ChatStatus._({
    required this.type,
    required this.displayText,
    required this.textColor,
    this.unreadCount,
  });

  factory ChatStatus.sent(DateTime sentAt) => ChatStatus._(
    type: ChatStatusType.sent,
    displayText: 'Sent ${_formatTimeAgo(sentAt)}',
    textColor: Colors.grey[400]!,
  );

  factory ChatStatus.seen(DateTime seenAt) => ChatStatus._(
    type: ChatStatusType.seen,
    displayText: 'Seen ${_formatTimeAgo(seenAt)}',
    textColor: Colors.grey[400]!,
  );

  factory ChatStatus.unreadMessages(int count) => ChatStatus._(
    type: ChatStatusType.unread,
    displayText: count > 9 ? '9+ unread messages' : '$count unread message${count > 1 ? 's' : ''}',
    textColor: Colors.blue[300]!,
    unreadCount: count,
  );

  factory ChatStatus.normal(String? lastMessageContent) => ChatStatus._(
    type: ChatStatusType.normal,
    displayText: lastMessageContent ?? 'No messages yet',
    textColor: Colors.grey[400]!,
  );

  static String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}

// User Model for search results
class User {
  final String id;
  final String username;
  final String? profileImageUrl;
  final String? email;

  User({
    required this.id,
    required this.username,
    this.profileImageUrl,
    this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      email: json['email'] as String?,
    );
  }
}

// Minimal ChatRoom Model (can be expanded later if you have a chat_rooms table)
class ChatRoom {
  final String id;
  final String otherUserId;
  final String otherUsername;
  final String? otherUserProfileUrl;
  final Message? lastMessage;
  final int unreadCount; // NEW
  final ChatStatus status; // NEW

  ChatRoom({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    this.otherUserProfileUrl,
    this.lastMessage,
    this.unreadCount = 0, // NEW
    required this.status, // NEW
  });
}

// --- Message Service for Supabase Interactions ---
class MessageService {
  final SupabaseClient _supabaseClient = Supabase.instance.client; // Use your existing Supabase client

  // Search users method - you can replace this with your existing method
  Future<List<User>> searchUsers(String query, String currentUserId) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _supabaseClient
          .from('users')
          .select('id, username, profile_image_url, email')
          .neq('id', currentUserId) // Exclude current user
          .ilike('username', '%$query%')
          .limit(20);

      return response.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Stream<List<Message>> getMessagesWithFunction({required String currentUserId, required String otherUserId}) {
    return _supabaseClient
        .rpc('get_messages_between_users', params: {
      'user1_id': currentUserId,
      'user2_id': otherUserId,
    })
        .asStream()
        .map((data) => (data as List).map((json) => Message.fromJson(json)).toList());
  }

  // Send a new message
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    String? content,
    String? imageUrl,
  }) async {
    if (content == null && imageUrl == null) {
      throw ArgumentError('Message must have content or an image.');
    }

    await _supabaseClient.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'image_url': imageUrl,
      'is_read': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int> getUnreadMessageCount(String currentUserId, String otherUserId) async {
    try {
      final response = await _supabaseClient
          .from('messages')
          .select('id')
          .eq('receiver_id', currentUserId)
          .eq('sender_id', otherUserId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  ChatStatus calculateChatStatus({
    required Message? lastMessage,
    required String currentUserId,
    required int unreadCount,
  }) {
    if (lastMessage == null) {
      return ChatStatus.normal(null);
    }

    // Check for unread messages from other user
    if (unreadCount > 0) {
      return ChatStatus.unreadMessages(unreadCount);
    }

    // Current user sent last message
    if (lastMessage.senderId == currentUserId) {
      if (lastMessage.isRead && lastMessage.seenAt != null) {
        return ChatStatus.seen(lastMessage.seenAt!);
      } else {
        return ChatStatus.sent(lastMessage.createdAt);
      }
    }

    // Other user sent last message and current user has read it
    return ChatStatus.normal(lastMessage.content ?? (lastMessage.imageUrl != null ? 'Sent a photo' : ''));
  }

  // Mark messages as read (optional, can be implemented later)
  Future<void> markMessagesAsRead({required String currentUserId, required String otherUserId}) async {
    await _supabaseClient
        .from('messages')
        .update({'is_read': true,'seen_at': DateTime.now().toUtc().toIso8601String(),})
        .eq('sender_id', otherUserId)
        .eq('receiver_id', currentUserId);
  }

  // Fetch a list of chat rooms (users with whom the current user has chatted)
  // This is a simplified approach, a dedicated 'chat_rooms' table would be more robust.
  Future<List<ChatRoom>> getChatRooms(String currentUserId) async {
    // Keep existing logic for getting participant IDs...
    final List<Map<String, dynamic>> sentMessages = await _supabaseClient
        .from('messages')
        .select('receiver_id, created_at, content, image_url')
        .eq('sender_id', currentUserId)
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> receivedMessages = await _supabaseClient
        .from('messages')
        .select('sender_id, created_at, content, image_url')
        .eq('receiver_id', currentUserId)
        .order('created_at', ascending: false);

    Set<String> participantIds = {};
    for (var msg in sentMessages) {
      participantIds.add(msg['receiver_id'] as String);
    }
    for (var msg in receivedMessages) {
      participantIds.add(msg['sender_id'] as String);
    }
    participantIds.remove(currentUserId);

    List<ChatRoom> chatRooms = [];
    for (String participantId in participantIds) {
      // Get last message
      final latestMessageQuery = await _supabaseClient
          .from('messages')
          .select('*')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$participantId),and(sender_id.eq.$participantId,receiver_id.eq.$currentUserId)')
          .order('created_at', ascending: false)
          .limit(1);

      Message? lastMessage;
      if (latestMessageQuery.isNotEmpty) {
        lastMessage = Message.fromJson(latestMessageQuery.first);
      }

      // Get unread count - NEW
      final unreadCount = await getUnreadMessageCount(currentUserId, participantId);

      // Get user profile
      final userProfile = await _supabaseClient
          .from('users')
          .select('username, profile_image_url')
          .eq('id', participantId)
          .single();

      // Calculate status - NEW
      final status = calculateChatStatus(
        lastMessage: lastMessage,
        currentUserId: currentUserId,
        unreadCount: unreadCount,
      );

      chatRooms.add(ChatRoom(
        id: ([currentUserId, participantId]..sort()).join('_'),
        otherUserId: participantId,
        otherUsername: userProfile['username'] as String? ?? 'Unknown User',
        otherUserProfileUrl: userProfile['profile_image_url'] as String?,
        lastMessage: lastMessage,
        unreadCount: unreadCount, // NEW
        status: status, // NEW
      ));
    }

    // Sort by last message time
    chatRooms.sort((a, b) {
      if (a.lastMessage == null && b.lastMessage == null) return 0;
      if (a.lastMessage == null) return 1;
      if (b.lastMessage == null) return -1;
      return b.lastMessage!.createdAt.compareTo(a.lastMessage!.createdAt);
    });

    return chatRooms;
  }
}

// --- New Chat Dialog Widget ---
class NewChatDialog extends StatefulWidget {
  final String currentUserId;
  final MessageService messageService;
  final Function(String userId, String username, String? profileUrl) onUserSelected;

  const NewChatDialog({
    Key? key,
    required this.currentUserId,
    required this.messageService,
    required this.onUserSelected,
  }) : super(key: key);

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final results = await widget.messageService.searchUsers(query, widget.currentUserId);

      // Only update if this is still the current search query
      if (_searchQuery == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (_searchQuery == query) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      print('Error searching users: $e');
    }
  }

  String _getProfileImageUrl(String? profileUrl) {
    if (profileUrl == null || profileUrl.isEmpty) {
      return 'https://via.placeholder.com/150'; // Default placeholder
    }
    if (profileUrl.startsWith('http://') || profileUrl.startsWith('https://')) {
      return profileUrl;
    }
    return 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$profileUrl';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Start typing to search for users',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(_getProfileImageUrl(user.profileImageUrl)),
            backgroundColor: Colors.grey[700],
            onBackgroundImageError: (exception, stackTrace) {
              print('Error loading profile image: $exception');
            },
          ),
          title: Text(
            user.username,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          subtitle: user.email != null
              ? Text(
            user.email!,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          )
              : null,
          onTap: () {
            Navigator.of(context).pop();
            widget.onUserSelected(user.id, user.username, user.profileImageUrl);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      },
    );
  }
}

// --- Chat Screen Widget ---
class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String? initialChatUserId;

  const ChatScreen({Key? key, required this.currentUserId, this.initialChatUserId}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessageService _messageService = MessageService();
  TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedChatUserId;
  String? _selectedChatUsername;
  String? _selectedChatUserProfileUrl;
  String? _currentUserUsername;

  // Add these for real-time chat room updates
  List<ChatRoom> _chatRooms = [];
  bool _isLoadingChatRooms = true;
  RealtimeChannel? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserUsername();
    _loadChatRooms(); // Load initial chat rooms
    _setupRealtimeSubscription(); // Setup real-time listener

    if (widget.initialChatUserId != null) {
      _selectedChatUserId = widget.initialChatUserId;
      _loadInitialChatUserInfo();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.unsubscribe(); // Clean up subscription
    super.dispose();
  }

  // Setup real-time subscription for messages
  void _setupRealtimeSubscription() {
    _messagesSubscription = Supabase.instance.client
        .channel('messages')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        // When any message is inserted, updated, or deleted, refresh chat rooms
        _loadChatRooms();
      },
    )
        .subscribe();
  }

  // Load chat rooms and update state
  Future<void> _loadChatRooms() async {
    try {
      final chatRooms = await _messageService.getChatRooms(widget.currentUserId);
      if (mounted) {
        setState(() {
          _chatRooms = chatRooms;
          _isLoadingChatRooms = false;
        });
      }
    } catch (e) {
      print('Error loading chat rooms: $e');
      if (mounted) {
        setState(() {
          _isLoadingChatRooms = false;
        });
      }
    }
  }

  // Load username and profile URL for initial chat if provided
  Future<void> _loadInitialChatUserInfo() async {
    if (_selectedChatUserId != null) {
      try {
        final userProfile = await Supabase.instance.client
            .from('users')
            .select('username, profile_image_url')
            .eq('id', _selectedChatUserId!)
            .single();

        setState(() {
          _selectedChatUsername = userProfile['username'] as String?;
          _selectedChatUserProfileUrl = userProfile['profile_image_url'] as String?;
        });
      } catch (e) {
        print('Error loading initial chat user info: $e');
        setState(() {
          _selectedChatUsername = 'Unknown User';
        });
      }
    }
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => NewChatDialog(
        currentUserId: widget.currentUserId,
        messageService: _messageService,
        onUserSelected: (userId, username, profileUrl) {
          setState(() {
            _selectedChatUserId = userId;
            _selectedChatUsername = username;
            _selectedChatUserProfileUrl = profileUrl;
          });
          _scrollToBottom();
        },
      ),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedChatUserId == null) {
      return;
    }
    try {
      await _messageService.sendMessage(
        senderId: widget.currentUserId,
        receiverId: _selectedChatUserId!,
        content: _messageController.text.trim(),
      );
      _messageController.clear();
      _scrollToBottom();

      // The real-time subscription will automatically update the chat room list
      // No need to manually refresh here
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatMessageTime(DateTime time) {
    if (DateTime.now().difference(time).inDays == 0) {
      return DateFormat('h:mm a').format(time);
    } else {
      return DateFormat('MMM d, h:mm a').format(time);
    }
  }

  Future<void> _loadCurrentUserUsername() async {
    final currentUserId = widget.currentUserId;
    try {
      final userProfile = await Supabase.instance.client
          .from('users')
          .select('username')
          .eq('id', currentUserId)
          .single();
      setState(() {
        _currentUserUsername = userProfile['username'] as String?;
      });
    } catch (e) {
      print('Error loading current user username: $e');
      setState(() {
        _currentUserUsername = 'Unknown User';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool inChatMode = _selectedChatUserId != null;

    String? publicImageUrl;
    if (inChatMode && _selectedChatUserProfileUrl != null) {
      publicImageUrl = _selectedChatUserProfileUrl!.startsWith('http://') || _selectedChatUserProfileUrl!.startsWith('https://')
          ? _selectedChatUserProfileUrl
          : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$_selectedChatUserProfileUrl';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: inChatMode
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _selectedChatUserId = null;
              _selectedChatUsername = null;
              _selectedChatUserProfileUrl = null;
            });
          },
        )
            : IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: inChatMode
            ? Row(
          children: [
            if (_selectedChatUserProfileUrl != null)
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(publicImageUrl!),
                backgroundColor: Colors.grey[800],
              ),
            const SizedBox(width: 8),
            Text(
              _selectedChatUsername ?? 'Chat',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        )
            : Text(
          _currentUserUsername ?? 'Chats',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!inChatMode)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 30),
              onPressed: _showNewChatDialog,
            ),
          if (inChatMode)
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                // TODO: Implement chat options
              },
            ),
        ],
      ),
      body: inChatMode ? _buildChatMessages() : _buildChatRoomList(),
    );
  }

  // Updated chat room list that uses state instead of FutureBuilder
  Widget _buildChatRoomList() {
    if (_isLoadingChatRooms) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chatRooms.isEmpty) {
      return const Center(
        child: Text(
          'No chats yet. Start a new conversation!',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChatRooms, // Allow manual refresh by pulling down
      child: ListView.builder(
        itemCount: _chatRooms.length,
        itemBuilder: (context, index) {
          final chatRoom = _chatRooms[index];
          final displayUrl = chatRoom.otherUserProfileUrl != null &&
              (chatRoom.otherUserProfileUrl!.startsWith('http://') ||
                  chatRoom.otherUserProfileUrl!.startsWith('https://'))
              ? chatRoom.otherUserProfileUrl!
              : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${chatRoom.otherUserProfileUrl}';

          return Padding(
            padding: const EdgeInsets.only(top:18),
            child: ListTile(
              leading: CircleAvatar(
                radius: 23,
                backgroundImage: NetworkImage(displayUrl),
                backgroundColor: Colors.grey[800],
                onBackgroundImageError: (exception, stackTrace) {
                  print('Error loading image: $exception');
                },
              ),
              title: Text(
                chatRoom.otherUsername,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                chatRoom.status.displayText,
                style: TextStyle(
                  color: chatRoom.status.textColor,
                  fontWeight: chatRoom.status.type == ChatStatusType.unread
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(onPressed: (){
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image sending coming soon!')),
                );
              }, icon: Icon(Icons.camera_alt, color: Colors.blue, size: 28)),
              onTap: () async {
                // Mark messages as read if needed
                if (chatRoom.lastMessage != null &&
                    chatRoom.lastMessage!.receiverId == widget.currentUserId &&
                    !chatRoom.lastMessage!.isRead) {
                  await _messageService.markMessagesAsRead(
                    currentUserId: widget.currentUserId,
                    otherUserId: chatRoom.otherUserId,
                  );
                }

                setState(() {
                  _selectedChatUserId = chatRoom.otherUserId;
                  _selectedChatUsername = chatRoom.otherUsername;
                  _selectedChatUserProfileUrl = chatRoom.otherUserProfileUrl;
                });
                _scrollToBottom();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatMessages() {
    if (_selectedChatUserId == null) {
      return const Center(
        child: Text('Select a chat to view messages', style: TextStyle(color: Colors.white)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: _messageService.getMessagesWithFunction(
              currentUserId: widget.currentUserId,
              otherUserId: _selectedChatUserId!,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('Say hello!', style: TextStyle(color: Colors.white)),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              final messages = snapshot.data!;
              return ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == widget.currentUserId;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[700] : Colors.grey[700],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
                          bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (message.content != null)
                            Text(
                              message.content!,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          if (message.imageUrl != null)
                            Text(
                              'Image: ${message.imageUrl!}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _formatMessageTime(message.createdAt),
                            style: TextStyle(
                              color: isMe ? Colors.blue[100] : Colors.grey[300],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left:8.0,right: 8,bottom: 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image sending coming soon!')),
                  );
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blueAccent),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}