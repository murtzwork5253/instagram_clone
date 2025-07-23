import 'dart:async';
import 'package:Instagram/screens/profilescreen/other_user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '/screens/chatscreen/model/models.dart'; // NEW: Import the new models file
import 'full_screen_image_viewer.dart';
import 'message_service.dart'; // NEW: Import the new message service file
import 'new_chat_dialog.dart'; // NEW: Import the new chat dialog file

// --- Enhanced Chat Screen ---
class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String? initialChatUserId;
  final bool? cameFromProfile; // NEW: Track if came from profile
  final VoidCallback? onMessageRead;
  final Message? initialMessage; // NEW

  const ChatScreen({
    Key? key,
    required this.currentUserId,
    this.initialChatUserId,
    this.cameFromProfile,
    this.onMessageRead,
    this.initialMessage, // NEW
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final MessageService _messageService = MessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late AnimationController _slideController;

  String? _selectedChatUserId;
  String? _selectedChatUsername;
  String? _selectedChatUserProfileUrl;
  String? _currentUserUsername;

  List<ChatRoom> _chatRooms = [];
  List<Message> _messages = [];
  bool _isLoadingChatRooms = true;
  bool _isLoadingMessages = false;
  RealtimeChannel? _messagesSubscription;
  bool _cameFromProfile = false; // NEW: Track navigation source
  // Image loading tracking
  final Set<String> _loadingImages = <String>{};
  final Set<String> _loadedImages = <String>{};
  bool _shouldScrollAfterImagesLoad = false;
  Timer? _scrollDelayTimer;

  // For smooth message animations
  final GlobalKey<AnimatedListState> _messageListKey = GlobalKey<AnimatedListState>();
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _cameFromProfile = widget.cameFromProfile ?? false; // NEW: Initialize the flag

    _loadCurrentUserUsername();
    _loadChatRooms();
    _setupRealtimeSubscription();

    if (widget.initialChatUserId != null) {
      _selectedChatUserId = widget.initialChatUserId;
      _loadInitialChatUserInfo();

      if(_cameFromProfile){
        _loadMessages();
      }
    }

    // Optimistic UI: Add initialMessage if provided and not already present
    if (widget.initialMessage != null) {
      final alreadyExists = _messages.any((m) => m.id == widget.initialMessage!.id);
      if (!alreadyExists) {
        setState(() {
          _messages.add(widget.initialMessage!);
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.unsubscribe();
    _scrollDelayTimer?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _messagesSubscription = Supabase.instance.client
        .channel('messages')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        // Handle real-time message updates more efficiently
        _handleRealtimeMessageUpdate(payload.newRecord as Map<String, dynamic>?);
      },
    )
        .subscribe();
  }

  // NEW CODE - Replace the above section with this:
  void _handleRealtimeMessageUpdate(Map<String, dynamic>? newData) {
    if (newData == null) {
      print('Realtime update received with null newData. Skipping.');
      return;
    }

    // Only refresh chat rooms list when not in active chat
    if (_selectedChatUserId == null) {
      _loadChatRooms();
      return;
    }

    final message = Message.fromJson(newData);

    // Check if the message already exists in the list to prevent duplicates
    final existingMessageIndex = _messages.indexWhere((m) => m.id == message.id);

    if (existingMessageIndex != -1) {
      // If the message exists, update it (e.g., status changes like read/delivered)
      setState(() {
        _messages[existingMessageIndex] = message;
      });
    } else {
      // Only add if it's part of current conversation
      if ((message.senderId == widget.currentUserId &&
          message.receiverId == _selectedChatUserId) ||
          (message.senderId == _selectedChatUserId &&
              message.receiverId == widget.currentUserId)) {

        setState(() {
          _messages.add(message);
        });

        // Animate new message
        if (_messageListKey.currentState != null) {
          _messageListKey.currentState?.insertItem(
            _messages.length - 1,
            duration: const Duration(milliseconds: 300),
          );
        }

        _scrollToBottomSmooth();

        // Mark as read if received from other user
        if (message.senderId == _selectedChatUserId) {
          _markCurrentChatAsRead();
        }
      }
    }

    // Always refresh chat rooms for updated status
    _loadChatRooms();
  }

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

  Future<void> _loadInitialChatUserInfo() async {
    if (_selectedChatUserId == null) return;

    try {
      final userProfile = await Supabase.instance.client
          .from('users')
          .select('username, profile_image_url')
          .eq('id', _selectedChatUserId!)
          .single();

      if (mounted) {
        setState(() {
          _selectedChatUsername = userProfile['username'] as String?;
          _selectedChatUserProfileUrl = userProfile['profile_image_url'] as String?;
        });
      }
    } catch (e) {
      print('Error loading initial chat user info: $e');
      if (mounted) {
        setState(() {
          _selectedChatUsername = 'Unknown User';
          _selectedChatUserProfileUrl = null;
        });
      }
    }
  }

  Future<void> _loadCurrentUserUsername() async {
    try {
      final userProfile = await Supabase.instance.client
          .from('users')
          .select('username')
          .eq('id', widget.currentUserId)
          .single();

      if (mounted) {
        setState(() {
          _currentUserUsername = userProfile['username'] as String?;
        });
      }
    } catch (e) {
      print('Error loading current user username: $e');
      if (mounted) {
        setState(() {
          _currentUserUsername = 'Unknown User';
        });
      }
    }
  }

  // Load messages initially without stream
  // Replace the existing _loadMessages method

  Future<void> _loadMessages() async {
    if (_selectedChatUserId == null) return;

    setState(() {
      _isLoadingMessages = true;
      // Reset image tracking
      _loadingImages.clear();
      _loadedImages.clear();
      _shouldScrollAfterImagesLoad = false;
    });

    try {
      final response = await Supabase.instance.client
          .rpc('get_messages_between_users', params: {
        'user1_id': widget.currentUserId,
        'user2_id': _selectedChatUserId!,
      });

      final messages = (response as List)
          .map((json) => Message.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
          _isFirstLoad = false;
        });

        // Check if there are images in messages
        final hasImages = _messages.any((msg) =>
        msg.imageUrl != null && msg.imageUrl!.isNotEmpty);

        if (hasImages) {
          // Set flag to scroll after images load
          _shouldScrollAfterImagesLoad = true;

          // Also set a fallback timer in case some images fail to trigger callbacks
          Timer(const Duration(seconds: 3), () {
            if (_shouldScrollAfterImagesLoad && mounted) {
              print('Fallback scroll triggered after 3 seconds');
              _performDelayedScroll();
            }
          });
        } else {
          // No images, scroll immediately but with small delay for ListView to build
          Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              _executeScroll();
            }
          });
        }

        // Mark messages as read
        _markCurrentChatAsRead();
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  // Improved scroll method
  void _scrollToAppropriatePosition() {
    // This method is now mainly used for immediate scrolling without images
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _executeScroll();
      }
    });
  }

  // Add these methods inside the _ChatScreenState class

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_selectedChatUserId == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70, // Compress image to reduce file size
      maxWidth: 1080,    // Resize image for faster uploads
    );

    if (image != null) {
      // Show a temporary loading indicator if needed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading image...')),
      );

      final imageUrl = await _messageService.uploadChatImage(
        imageFile: image,
        userId: widget.currentUserId,
      );

      if (imageUrl != null) {
        await _messageService.sendMessage(
          senderId: widget.currentUserId,
          receiverId: _selectedChatUserId!,
          imageUrl: imageUrl,
          content: '📷 Photo', // Optional: add content for notifications
        );
        _loadMessages(); // Refresh messages after sending
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image. Please try again.')),
          );
        }
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.white),
                title: const Text('Camera', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // void _scrollToFirstUnreadOrBottom() {
  //   _scrollToAppropriatePosition(); // Use the new improved method
  // }

  Future<void> _markCurrentChatAsRead() async {
    if (_selectedChatUserId == null) return;

    try {
      await _messageService.markMessagesAsRead(
        currentUserId: widget.currentUserId,
        otherUserId: _selectedChatUserId!,
      );

      // Notify parent widget that messages were read
      widget.onMessageRead?.call();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Update _scrollToBottomSmooth for new message arrivals
  void _scrollToBottomSmooth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedChatUserId == null) {
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      await _messageService.sendMessage(
        senderId: widget.currentUserId,
        receiverId: _selectedChatUserId!,
        content: messageText,
      );
      _loadMessages();

      // Note: Real-time subscription will handle adding the message to UI
    } catch (e) {
      print('Error sending message: $e');
      // Restore message text on error
      _messageController.text = messageText;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _selectChat(String userId, String username, String? profileUrl) async {
    // Mark previous chat as read before switching
    if (_selectedChatUserId != null) {
      await _markCurrentChatAsRead();
    }

    setState(() {
      _selectedChatUserId = userId;
      _selectedChatUsername = username;
      _selectedChatUserProfileUrl = profileUrl;
      _messages.clear();
      _isFirstLoad = true;
    });

    // Load messages for new chat
    await _loadMessages();

    // Animate transition
    _fadeController.forward();
    _slideController.forward();
  }

  void _exitChat() async {
    // Mark messages as read before exiting
    if (_selectedChatUserId != null) {
      await _markCurrentChatAsRead();
    }

    setState(() {
      _selectedChatUserId = null;
      _selectedChatUsername = null;
      _selectedChatUserProfileUrl = null;
      _messages.clear();
    });

    // Refresh chat rooms to update unread counts
    await _loadChatRooms();

    _fadeController.reverse();
    _slideController.reverse();

    widget.onMessageRead?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool inChatMode = _selectedChatUserId != null;

    return PopScope(
      canPop: _selectedChatUserId == null,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        if (_selectedChatUserId != null) {
          // Mark messages as read before navigating away
          await _markCurrentChatAsRead();
          // If in chat mode, check if we came from profile
          if (_cameFromProfile) {
            // Go back to the previous screen (profile)
            Navigator.of(context).pop();
          } else {
            // Just exit chat mode, stay in ChatScreen
            _exitChat();
          }
        } else {
          Navigator.of(context).pop(); // Pop the whole route
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildAppBar(inChatMode),
        body: inChatMode ? _buildChatMessages() : _buildChatRoomList(),
      ),
    );


  }

  PreferredSizeWidget _buildAppBar(bool inChatMode) {
    String? publicImageUrl;
    if (inChatMode && _selectedChatUserProfileUrl != null) {
      publicImageUrl = _selectedChatUserProfileUrl!.startsWith('http://') ||
          _selectedChatUserProfileUrl!.startsWith('https://')
          ? _selectedChatUserProfileUrl
          : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$_selectedChatUserProfileUrl';
    }

    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: (){
          if(inChatMode == true)
              if (_cameFromProfile)
                Navigator.of(context).pop();
              else
                _exitChat();
          else
            Navigator.of(context).pop();
        },
      ),
      title: inChatMode
          ? GestureDetector(
        onTap: () {
          // TODO: Navigate to user profile
          Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileScreen(userId: _selectedChatUserId!)));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'profile_$_selectedChatUserId',
              child: CircleAvatar(
                radius: 16,
                backgroundImage: publicImageUrl != null
                    ? NetworkImage(publicImageUrl)
                    : null,
                backgroundColor: Colors.grey[800],
                child: publicImageUrl == null
                    ? const Icon(Icons.person, color: Colors.white, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedChatUsername ?? 'Chat',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600
                  ),
                ),
              ],
            ),
          ],
        ),
      )
          : Row(
        children: [
          Text(
            _currentUserUsername ?? 'Messages',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold
            ),
          ),
          // const SizedBox(width: 8),
          // if (_chatRooms.isNotEmpty)
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          //     decoration: BoxDecoration(
          //       color: Colors.grey[800],
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     child: Text(
          //       '${_chatRooms.length}',
          //       style: TextStyle(
          //         color: Colors.grey[300],
          //         fontSize: 12,
          //         fontWeight: FontWeight.w500,
          //       ),
          //     ),
          //   ),
        ],
      ),
      actions: [
        if (!inChatMode) ...[
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.white, size: 24),
            onPressed: _showNewChatDialog,
            tooltip: 'New message',
          ),
        ] else ...[
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.grey[900],
            onSelected: (value) {
              switch (value) {
                case 'mute':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mute notifications')),
                  );
                  break;
                case 'delete':
                  _showDeleteChatDialog();
                  break;
                case 'block':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Block user')),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(Icons.notifications_off, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Mute', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Delete chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Block', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Replace the existing _showDeleteChatDialog method in ChatScreen

  void _showDeleteChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete this chat with ${_selectedChatUsername}? This will permanently delete all messages and cannot be undone.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog first
              await _deleteChatRoom();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

// Add this new method to handle chat deletion
  Future<void> _deleteChatRoom() async {
    if (_selectedChatUserId == null) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting chat...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Delete the chat room
      await _messageService.deleteChatRoom(
        currentUserId: widget.currentUserId,
        otherUserId: _selectedChatUserId!,
      );

      // Clear current chat state
      setState(() {
        _selectedChatUserId = null;
        _selectedChatUsername = null;
        _selectedChatUserProfileUrl = null;
        _messages.clear();
      });

      // Refresh chat rooms list
      await _loadChatRooms();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Call onMessageRead to update parent if needed
      widget.onMessageRead?.call();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildChatMessages() {
    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    // Build a list of widgets with date separators
    List<Widget> messageWidgets = [];
    DateTime? lastDate;
    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      final messageDate = DateTime(message.createdAt.year, message.createdAt.month, message.createdAt.day);
      if (lastDate == null || messageDate != lastDate) {
        messageWidgets.add(_buildDateSeparator(messageDate));
        lastDate = messageDate;
      }
      messageWidgets.add(_buildAnimatedMessageItem(message, kAlwaysCompleteAnimation));
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text('Say hello!', style: TextStyle(color: Colors.white)),
                )
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  children: messageWidgets,
                ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  // Helper for always-complete animation (for non-animated list)
  static final kAlwaysCompleteAnimation = AlwaysStoppedAnimation<double>(1.0);

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMessageItem(Message message, Animation<double> animation) {
    final isMe = message.senderId == widget.currentUserId;

    Widget messageContent;
    if (message.sharedPost != null) {
      // Render shared post preview card
      final shared = message.sharedPost!;
      final String imageUrl = (shared['image_url'] ?? '').toString();
      final String username = (shared['username'] ?? '');
      final String caption = (shared['caption'] ?? '');
      final String? profileImageUrl = shared['profile_image_url'];
      final String postId = shared['post_id'] ?? '';
      final String userId = shared['user_id'] ?? '';

      messageContent = GestureDetector(
        onTap: () async {
        },
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[800]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtherUserProfileScreen(userId: userId),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                          ? NetworkImage(profileImageUrl.startsWith('http') ? profileImageUrl : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$profileImageUrl')
                          : null,
                      backgroundColor: Colors.grey[800],
                      child: (profileImageUrl == null || profileImageUrl.isEmpty)
                          ? const Icon(Icons.person, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtherUserProfileScreen(userId: userId),
                          ),
                        );
                      },
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[800],
                          height: 180,
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.white)),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        height: 180,
                        child: const Center(child: Icon(Icons.broken_image, color: Colors.white)),
                      ),
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  caption,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Shared a post',
                style: TextStyle(color: Colors.blue[200], fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }
    else if (message.imageUrl != null && message.imageUrl!.isNotEmpty) {
      print("DEBUG: Image URL is : ${message.imageUrl}");

      // Track this image as loading if not already loaded
      if (!_loadedImages.contains(message.id)) {
        _loadingImages.add(message.id);
      }

      messageContent = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenImageViewer(
                imageUrl: message.imageUrl!,
                heroTag: 'image_${message.id}',
              ),
            ),
          );
        },
        child: Hero(
          tag: 'image_${message.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: Image.network(
                message.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) {
                    // Image loaded successfully
                    _onImageLoaded(message.id);
                    return child;
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  // Remove from loading set on error
                  _onImageLoadError(message.id);
                  return Container(
                    color: Colors.grey[800],
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.broken_image, color: Colors.white, size: 40),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }
    else if (message.content != null && message.content!.isNotEmpty) {
      // Render text message
      messageContent = Text(
        message.content!,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      );
    } else {
      // Fallback for empty/unknown message
      messageContent = const SizedBox.shrink();
    }

    return SlideTransition(
      position: animation.drive(
        Tween(begin: const Offset(0, 0.3), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut)),
      ),
      child: FadeTransition(
        opacity: animation,
        child: GestureDetector(
          onLongPress: () {
            // Only allow deletion of own messages
            if (message.senderId == widget.currentUserId) {
              HapticFeedback.mediumImpact();
              _showMessageDeleteDialog(message);
            }
          },
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: message.sharedPost != null
                    ? (isMe ? Colors.blue[900] : Colors.grey[850])
                    : (isMe ? Colors.blue[700] : Colors.grey[700]),
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
                  messageContent,
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(message.createdAt),
                    style: TextStyle(
                      color: isMe ? Colors.blue[100] : Colors.grey[300],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Add these methods to your _ChatScreenState class

  // Replace the image loading callback methods with this even safer version

  void _onImageLoaded(String messageId) {
    // Use Future.microtask to ensure we're not in build context
    Future.microtask(() {
      if (mounted) {
        _loadingImages.remove(messageId);
        _loadedImages.add(messageId);

        // Check if all images are loaded and we need to scroll
        if (_shouldScrollAfterImagesLoad && _loadingImages.isEmpty) {
          _performDelayedScroll();
        }
      }
    });
  }

  void _onImageLoadError(String messageId) {
    // Use Future.microtask to ensure we're not in build context
    Future.microtask(() {
      if (mounted) {
        _loadingImages.remove(messageId);
        // Don't add to loaded images since it failed

        // Still check if we need to scroll (treat error as "loaded" for scroll purposes)
        if (_shouldScrollAfterImagesLoad && _loadingImages.isEmpty) {
          _performDelayedScroll();
        }
      }
    });
  }

// Update _performDelayedScroll to not use setState directly
  void _performDelayedScroll() {
    _shouldScrollAfterImagesLoad = false;

    // Cancel any existing timer
    _scrollDelayTimer?.cancel();

    // Wait a bit more for any final adjustments
    _scrollDelayTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _executeScroll();
      }
    });
  }

  void _executeScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    try {
      final currentUserId = widget.currentUserId;

      // Find first unread message from other user
      int firstUnreadIndex = -1;
      for (int i = 0; i < _messages.length; i++) {
        final msg = _messages[i];
        if (!msg.isRead &&
            msg.receiverId == currentUserId &&
            msg.senderId == _selectedChatUserId) {
          firstUnreadIndex = i;
          break;
        }
      }

      final maxScrollExtent = _scrollController.position.maxScrollExtent;

      if (firstUnreadIndex != -1 && maxScrollExtent > 0) {
        // Scroll to first unread message with some padding
        final targetPosition = (maxScrollExtent * 0.7).clamp(0.0, maxScrollExtent);

        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        // No unread messages, scroll to bottom
        _scrollController.animateTo(
          maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Error during delayed scroll: $e');
    }
  }

  void _showMessageDeleteDialog(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteSingleMessage(message);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSingleMessage(Message message) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting message...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );

      final success = await _messageService.deleteSingleMessage(
        messageId: message.id,
        currentUserId: widget.currentUserId,
      );

      if (success) {
        // Remove message from local list
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });

        // Refresh chat rooms to update last message if needed
        _loadChatRooms();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8, bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
              onPressed: _showImageSourceDialog,
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
    );
  }

  Widget _buildChatRoomList() {
    if (_isLoadingChatRooms) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    }

    if (_chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with someone',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showNewChatDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Message', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChatRooms,
      color: Colors.white,
      backgroundColor: Colors.grey[800],
      child: CustomScrollView(
        slivers: [
          // Search bar section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search messages',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  // TODO: Implement search functionality
                },
              ),
            ),
          ),
          // Chat rooms list
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return _buildChatRoomItem(_chatRooms[index], index);
              },
              childCount: _chatRooms.length,
            ),
          ),
        ],
      ),
    );
  }

  // Replace the existing _buildChatRoomItem method in ChatScreen
  Widget _buildChatRoomItem(ChatRoom chatRoom, int index) {
    final String displayUrl;
    if(chatRoom.otherUserProfileUrl == null){
      displayUrl = '';
    }
    else if (chatRoom.otherUserProfileUrl!.startsWith('http://') ||
        chatRoom.otherUserProfileUrl!.startsWith('https://')) {
      displayUrl = chatRoom.otherUserProfileUrl!;
    } else {
      displayUrl = 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${chatRoom.otherUserProfileUrl}';
    }

    final hasUnreadMessages = chatRoom.status.type == ChatStatusType.unread;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectChat(
            chatRoom.otherUserId,
            chatRoom.otherUsername,
            chatRoom.otherUserProfileUrl,
          ),
          onLongPress: () => _showDeleteChatFromListDialog(chatRoom), // Add long press
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Profile picture with online indicator
                Stack(
                  children: [
                    Hero(
                      tag: 'profile_${chatRoom.otherUserId}',
                      child: Container(
                        child: CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(displayUrl),
                          child: displayUrl == '' ? const Icon(Icons.person, color: Colors.white, size: 24) : null,
                          backgroundColor: Colors.grey[800],
                          onBackgroundImageError: (exception, stackTrace) {
                            print('Error loading image: $exception');
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Chat info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              chatRoom.otherUsername,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: hasUnreadMessages
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Time and status
                      Text(
                        chatRoom.status.displayText, // Use the new status display
                        style: TextStyle(
                          color: chatRoom.status.textColor, // Use the new status color
                          fontSize: 14,
                          fontWeight: hasUnreadMessages
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Camera button
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    onPressed: () => _sendCameraImageToChat(chatRoom), // Updated functionality
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.grey[500],
                      size: 22,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add this new method for delete dialog from chat list
  void _showDeleteChatFromListDialog(ChatRoom chatRoom) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete this chat with ${chatRoom.otherUsername}? This will permanently delete all messages and cannot be undone.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog first
              await _deleteChatFromList(chatRoom);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Add this method to handle deletion from chat list
  Future<void> _deleteChatFromList(ChatRoom chatRoom) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting chat...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Delete the chat room
      await _messageService.deleteChatRoom(
        currentUserId: widget.currentUserId,
        otherUserId: chatRoom.otherUserId,
      );

      // Refresh chat rooms list
      await _loadChatRooms();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Call onMessageRead to update parent if needed
      widget.onMessageRead?.call();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendCameraImageToChat(ChatRoom chatRoom) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera, // Only camera, not gallery
      imageQuality: 70, // Compress image to reduce file size
      maxWidth: 1080,    // Resize image for faster uploads
    );

    if (image != null) {
      // Show a temporary loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sending photo to ${chatRoom.otherUsername}...'),
          duration: const Duration(seconds: 3),
        ),
      );

      try {
        // Upload the image
        final imageUrl = await _messageService.uploadChatImage(
          imageFile: image,
          userId: widget.currentUserId,
        );

        if (imageUrl != null) {
          // Send the message with the image
          await _messageService.sendMessage(
            senderId: widget.currentUserId,
            receiverId: chatRoom.otherUserId,
            imageUrl: imageUrl,
            content: '📷 Photo', // Optional: add content for notifications
          );

          // Refresh chat rooms to show the new message
          _loadChatRooms();

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo sent to ${chatRoom.otherUsername}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload image. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send photo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  // Update _getLastMessagePreview to show 'Shared a post' if last message is a shared post
  String _getLastMessagePreview(ChatRoom chatRoom) {
    if (chatRoom.lastMessage == null) {
      return 'Start a conversation';
    }

    final message = chatRoom.lastMessage!;
    final isFromCurrentUser = message.senderId == widget.currentUserId;

    if (message.sharedPost != null) {
      return isFromCurrentUser ? 'You shared a post' : 'Shared a post';
    }

    String preview = '';
    if (message.imageUrl != null) {
      preview = isFromCurrentUser ? 'You sent a photo' : 'Sent a photo';
    } else if (message.content != null) {
      preview = isFromCurrentUser
          ? 'You: ${message.content!}'
          : message.content!;
    }
    return preview.isEmpty ? 'New message' : preview;
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => NewChatDialog(
        currentUserId: widget.currentUserId,
        messageService: _messageService,
        onUserSelected: _selectChat,
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    if (DateTime.now().difference(time).inDays == 0) {
      return DateFormat('h:mm a').format(time);
    } else {
      return DateFormat('MMM d, h:mm a').format(time);
    }
  }
}