import 'dart:io';
import 'dart:math' as math;
import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart'; // Import provider package
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/insta_data_provider.dart';
import '../../../services/supabase_service.dart';
import '../../user_tagging/user_model.dart';
import '../../user_tagging/user_tagging_screen.dart'; // <-- Adjust this import path!
import '../../user_tagging/user_tagging_service.dart';

class StoryPreviewScreen extends StatefulWidget {
  final String imagePath; // Path to the captured image or selected image
  final bool isFrontCamera;

  const StoryPreviewScreen({Key? key, required this.imagePath, this.isFrontCamera=false}) : super(key: key);

  State<StoryPreviewScreen> createState() => StoryPreviewScreenState();
}

class StoryPreviewScreenState extends State<StoryPreviewScreen> {
  bool _isUploading = false;
  List<TaggedUser> _taggedUsers = [];
  final UserTaggingService _taggingService = UserTaggingService();
  String? _currentStoryId;

  void _openTextOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Text',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type your text here...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  Container(
                    height: 40,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Color picker buttons
                        _buildColorButton(Colors.white),
                        _buildColorButton(Colors.black),
                        _buildColorButton(Colors.red),
                        _buildColorButton(Colors.blue),
                        _buildColorButton(Colors.green),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Text added to story!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Add', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return GestureDetector(
      onTap: () {
        // Handle color selection
      },
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1),
        ),
      ),
    );
  }

  void _openTaggingScreen() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to tag users. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserTaggingScreen(
          currentUserId: currentUserId,
          initialTaggedUsers: _taggedUsers,
          title: 'Tag People in Story',
          onUsersSelected: (selectedUsers) {
            setState(() {
              _taggedUsers = selectedUsers;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTaggedUsersList() {
    if (_taggedUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _taggedUsers.length,
        itemBuilder: (context, index) {
          final user = _taggedUsers[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: user.profileImageUrl != null
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: user.profileImageUrl == null
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                Text(
                  user.username,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full-screen Image Preview with 9:16 Aspect Ratio
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: widget.isFrontCamera
                    ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi), // Mirror the front camera image
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                  ),
                )
                    : Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // 2. Top Action Icons Row (More prominent and slightly larger)
          Positioned(
            top: MediaQuery.of(context).padding.top + 2,
            left: 10,
            right: 10,
            child: Row(
              children: [
                // Back button (X icon)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.of(context).pop(); // Go back to camera screen
                  },
                ),
                const Spacer(), // Pushes icons to the right

                // More Instagram-like icons
                _buildTopActionIcon(Icons.person_add_alt_1_outlined, () {
                  _openTaggingScreen();
                }),
                _buildTopActionIcon(Icons.text_fields, () {
                  _openTextOverlay();
                }),
                _buildTopActionIcon(Icons.brush_outlined, () {
                  // Handle drawing/doodling
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Draw (Not Implemented)')));
                }),
                _buildTopActionIcon(Icons.sticky_note_2_outlined, () {
                  // Handle adding stickers/GIFs
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add Sticker/GIF (Not Implemented)')));
                }),
                _buildTopActionIcon(Icons.music_note_outlined, () {
                  _openMusicMode();
                }),
                _buildTopActionIcon(Icons.more_vert, () {
                }),
              ],
            ),
          ),

          // Tagged Users List
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: _buildTaggedUsersList(),
          ),

          // 3. Bottom Action Buttons (Your Story, Close Friends, Send To)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // "Your Story" Button
                  _buildBottomActionButton(
                    label: 'Your story',
                    icon: _isUploading
                        ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                    onTap: _isUploading
                        ? () {}
                        : () async {
                      setState(() => _isUploading = true);

                      final String? uploadedUrl =
                      await SupabaseService.uploadStoryMedia(File(widget.imagePath));

                      if (uploadedUrl != null) {
                        // Create story and get the story ID
                        final storyId = await Provider.of<InstaDataProvider>(context, listen: false)
                            .createStory(uploadedUrl);

                        if (storyId != null && _taggedUsers.isNotEmpty) {
                          // Save tagged users to the story
                          await _taggingService.saveTaggedUsersToStory(
                            storyId: storyId,
                            taggedUsers: _taggedUsers,
                          );
                        }

                        // Refresh stories
                        Provider.of<InstaDataProvider>(context, listen: false).reloadData();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      } else {
                        Fluttertoast.showToast(msg: "Failed to upload story media.");
                      }
                    },
                  ),

                  // "Close Friends" Button
                  _buildBottomActionButton(
                    label: 'Close Friends',
                    icon: Icon(Icons.star_border,color: Colors.greenAccent,size: 20,), // Star icon for Close Friends
                    onTap: () {
                      // Logic to post to Close Friends
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Posting to Close Friends!')));
                      Navigator.of(context).pop(); // Go back to main feed
                    },
                  ),

                  // "Send To" / Share Button
                  Padding(
                    padding: const EdgeInsets.only(left: 15.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, // White background for the main share button
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20), // Forward arrow
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Working On It.',style: TextStyle(fontSize: 16),)),
                          );
                          // // Logic to open share sheet
                          // _showShareSheet(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for top action icons
  Widget _buildTopActionIcon(IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
      ),
    );
  }

  void _openMusicMode() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Add Music',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search music...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              // Music categories
              Container(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildMusicCategory('Popular', true),
                    _buildMusicCategory('Trending', false),
                    _buildMusicCategory('Mood', false),
                    _buildMusicCategory('Genre', false),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 15,
                  itemBuilder: (context, index) => _buildMusicItem(index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusicCategory(String name, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[400],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildMusicItem(int index) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note, color: Colors.white),
      ),
      title: Text('Song Title $index', style: const TextStyle(color: Colors.white)),
      subtitle: Text('Artist Name $index', style: TextStyle(color: Colors.grey[500])),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow, color: Colors.white),
        onPressed: () {
          // Play preview
        },
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Song $index added to story!')),
        );
      },
    );
  }

  // Helper method for bottom action buttons
  Widget _buildBottomActionButton({
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800], // Slightly darker background for buttons
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha:0.3), width: 1), // Subtle border
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 15,color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              // Remove the SizedBox wrapper and explicit height
              child: Column(
                mainAxisSize: MainAxisSize.min, // Add this
                children: [
                  // Handle for dragging the sheet
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Share',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  // Use Flexible instead of Expanded to allow the column to size itself
                  Flexible(
                    child: ListView(
                      controller: scrollController,
                      shrinkWrap: true, // Add this
                      padding: const EdgeInsets.only(top: 8),
                      children: [
                        // Suggested friends
                        _buildShareRecipientList('Suggested', [
                          _buildShareRecipientItem('Alice', context, 'https://randomuser.me/api/portraits/women/1.jpg'),
                          _buildShareRecipientItem('Bob', context, 'https://randomuser.me/api/portraits/men/2.jpg'),
                          _buildShareRecipientItem('Charlie', context, 'https://randomuser.me/api/portraits/men/3.jpg'),
                          _buildShareRecipientItem('Diana', context, 'https://randomuser.me/api/portraits/women/4.jpg'),
                        ], isHorizontal: true),

                        // Recent chats
                        _buildShareRecipientList('Recent', [
                          _buildShareRecipientItem('Eve', context, 'https://randomuser.me/api/portraits/women/5.jpg', message: 'Hello!'),
                          _buildShareRecipientItem('Frank', context, 'https://randomuser.me/api/portraits/men/6.jpg', message: 'Cool story!'),
                          _buildShareRecipientItem('Grace', context, 'https://randomuser.me/api/portraits/women/7.jpg'),
                        ]),

                        // Other options
                        ListTile(
                          leading: Icon(Icons.download_for_offline_outlined, color: Colors.white),
                          title: Text('Save Story', style: TextStyle(color: Colors.white)),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story Saved!')));
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.share, color: Colors.white),
                          title: Text('Share to other apps', style: TextStyle(color: Colors.white)),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Share Dialog!')));
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  // Send button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story Sent!')));
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Send',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShareRecipientList(String title, List<Widget> items, {bool isHorizontal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Add this
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        isHorizontal
            ? SizedBox( // Use SizedBox instead of Container
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            children: items,
          ),
        )
            : Column(
          mainAxisSize: MainAxisSize.min, // Add this
          children: items,
        ),
      ],
    );
  }

  Widget _buildShareRecipientItem(String name,BuildContext context, String avatarUrl, {String? message}) {
    return SizedBox(
      height: 70, // Fixed height for each item
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(avatarUrl),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white)),
        subtitle: message != null ? Text(message, style: TextStyle(color: Colors.grey[500])) : null,
        trailing: Container(
          width: 24, // Checkbox size
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: const Icon(Icons.check, color: Colors.blue, size: 16), // Or an empty circle if not selected
        ),
        onTap: () {
          // Handle selection for sharing
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selected $name for sharing!')));
          // In a real app, you'd manage a list of selected recipients
        },
      ),
    );
  }
}