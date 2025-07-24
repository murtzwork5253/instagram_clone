import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../../services/insta_data_provider.dart';
import '../../../services/supabase_service.dart';
import '../../user_tagging/user_model.dart';
import '../../user_tagging/user_tagging_screen.dart';
import '../../user_tagging/user_tagging_service.dart';

// Text Overlay Model
class TextOverlay {
  String text;
  Offset position;
  double scale;
  double rotation;
  Color textColor;
  Color backgroundColor;
  TextAlign alignment;
  String fontStyle;
  bool isSelected;

  TextOverlay({
    required this.text,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.textColor = Colors.white,
    this.backgroundColor = Colors.transparent,
    this.alignment = TextAlign.center,
    this.fontStyle = 'Classic',
    this.isSelected = false,
  });
}

class StoryPreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool isFrontCamera;

  const StoryPreviewScreen({Key? key, required this.imagePath, this.isFrontCamera = false}) : super(key: key);

  @override
  State<StoryPreviewScreen> createState() => StoryPreviewScreenState();
}

class StoryPreviewScreenState extends State<StoryPreviewScreen> {
  bool _isUploading = false;
  List<TaggedUser> _taggedUsers = [];
  final UserTaggingService _taggingService = UserTaggingService();
  String? _currentStoryId;

  // Text overlay properties
  List<TextOverlay> _textOverlays = [];
  TextOverlay? _selectedOverlay;
  final GlobalKey _imageKey = GlobalKey();

  // Share functionality
  List<String> _selectedRecipients = [];

  void _openTextOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TextOverlayDialog(
        onTextAdded: (text, style, color, backgroundColor) {
          _addTextOverlay(text, style, color, backgroundColor);
        },
      ),
    );
  }

  void _addTextOverlay(String text, String style, Color textColor, Color backgroundColor) {
    if (text.trim().isEmpty) return;

    setState(() {
      // Deselect all other overlays
      for (var overlay in _textOverlays) {
        overlay.isSelected = false;
      }

      // Add new overlay at center
      final newOverlay = TextOverlay(
        text: text,
        position: const Offset(0.5, 0.5), // Center position (relative to image)
        textColor: textColor,
        backgroundColor: backgroundColor,
        fontStyle: style,
        isSelected: true,
      );

      _textOverlays.add(newOverlay);
      _selectedOverlay = newOverlay;
    });
  }

  void _selectOverlay(TextOverlay overlay) {
    setState(() {
      if (overlay.isSelected) {
        // If already selected, deselect it
        overlay.isSelected = false;
        _selectedOverlay = null;
      } else {
        // Deselect all other overlays
        for (var o in _textOverlays) {
          o.isSelected = false;
        }
        // Select the tapped overlay
        overlay.isSelected = true;
        _selectedOverlay = overlay;
      }
    });
  }

  void _deleteSelectedOverlay() {
    if (_selectedOverlay != null) {
      setState(() {
        _textOverlays.remove(_selectedOverlay);
        _selectedOverlay = null;
      });
    }
  }

  void _editSelectedOverlay() {
    if (_selectedOverlay == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TextOverlayDialog(
        initialText: _selectedOverlay!.text,
        initialStyle: _selectedOverlay!.fontStyle,
        initialColor: _selectedOverlay!.textColor,
        initialBackgroundColor: _selectedOverlay!.backgroundColor,
        onTextAdded: (text, style, color, backgroundColor) {
          setState(() {
            _selectedOverlay!.text = text;
            _selectedOverlay!.fontStyle = style;
            _selectedOverlay!.textColor = color;
            _selectedOverlay!.backgroundColor = backgroundColor;
          });
        },
      ),
    );
  }

  Future<File> _captureImageWithOverlays() async {
    try {
      final RenderRepaintBoundary boundary = _imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'story_with_overlays_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File(path.join(tempDir.path, fileName));

      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      print('Error capturing image with overlays: $e');
      return File(widget.imagePath); // Fallback to original image
    }
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

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle for dragging the sheet
                      Container(
                        height: 4,
                        width: 40,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Share Story',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 24),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search people...',
                              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                              prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 22),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),

                      // Content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            const SizedBox(height: 10),

                            // Suggested Section
                            _buildShareSection(
                              'Suggested',
                              [
                                _buildSuggestedUserItem('Alice Johnson', 'alice_j', 'https://randomuser.me/api/portraits/women/1.jpg', setModalState),
                                _buildSuggestedUserItem('Bob Smith', 'bob_smith', 'https://randomuser.me/api/portraits/men/2.jpg', setModalState),
                                _buildSuggestedUserItem('Charlie Brown', 'charlie_b', 'https://randomuser.me/api/portraits/men/3.jpg', setModalState),
                                _buildSuggestedUserItem('Diana Prince', 'diana_p', 'https://randomuser.me/api/portraits/women/4.jpg', setModalState),
                                _buildSuggestedUserItem('Eva Martinez', 'eva_m', 'https://randomuser.me/api/portraits/women/5.jpg', setModalState),
                              ],
                              isHorizontal: true,
                            ),

                            const SizedBox(height: 20),

                            // Recent Chats Section
                            _buildShareSection(
                              'Recent',
                              [
                                _buildRecipientItem('Frank Wilson', 'frank_w', 'https://randomuser.me/api/portraits/men/6.jpg', 'Hey! 👋', setModalState),
                                _buildRecipientItem('Grace Lee', 'grace_l', 'https://randomuser.me/api/portraits/women/7.jpg', 'Nice photo!', setModalState),
                                _buildRecipientItem('Henry Davis', 'henry_d', 'https://randomuser.me/api/portraits/men/8.jpg', 'Thanks for sharing', setModalState),
                                _buildRecipientItem('Ivy Chen', 'ivy_c', 'https://randomuser.me/api/portraits/women/9.jpg', '😊', setModalState),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Other Options
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  _buildOptionTile(
                                    Icons.bookmark_outline,
                                    'Save Story',
                                    'Save to your device',
                                        () {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Story saved to device!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                  ),
                                  Divider(color: Colors.grey[700], height: 1),
                                  _buildOptionTile(
                                    Icons.share_outlined,
                                    'Share to other apps',
                                    'WhatsApp, Telegram, etc.',
                                        () {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Opening system share...'),
                                          backgroundColor: Colors.blue,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),

                      // Send button
                      if (_selectedRecipients.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            border: Border(top: BorderSide(color: Colors.grey[700]!)),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Story sent to ${_selectedRecipients.length} people!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              setState(() {
                                _selectedRecipients.clear();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            child: Text(
                              'Send to ${_selectedRecipients.length} ${_selectedRecipients.length == 1 ? 'person' : 'people'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
      },
    );
  }

  Widget _buildShareSection(String title, List<Widget> items, {bool isHorizontal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        isHorizontal
            ? SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: items,
          ),
        )
            : Column(children: items),
      ],
    );
  }

  Widget _buildSuggestedUserItem(String name, String username, String avatarUrl, StateSetter setModalState) {
    final isSelected = _selectedRecipients.contains(username);

    return GestureDetector(
      onTap: () {
        setModalState(() {
          if (isSelected) {
            _selectedRecipients.remove(username);
          } else {
            _selectedRecipients.add(username);
          }
        });
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
                if (isSelected)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name.split(' ')[0],
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientItem(String name, String username, String avatarUrl, String? lastMessage, StateSetter setModalState) {
    final isSelected = _selectedRecipients.contains(username);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(avatarUrl),
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: lastMessage != null
          ? Text(
        lastMessage,
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      )
          : null,
      trailing: GestureDetector(
        onTap: () {
          setModalState(() {
            if (isSelected) {
              _selectedRecipients.remove(username);
            } else {
              _selectedRecipients.add(username);
            }
          });
        },
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? Colors.blue : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[600]!,
              width: 2,
            ),
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
      ),
      onTap: () {
        setModalState(() {
          if (isSelected) {
            _selectedRecipients.remove(username);
          } else {
            _selectedRecipients.add(username);
          }
        });
      },
    );
  }

  Widget _buildOptionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: Colors.white, size: 24),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen Image Preview with Text Overlays
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: RepaintBoundary(
                  key: _imageKey,
                  child: Stack(
                    children: [
                      // Base Image
                      Positioned.fill(
                        child: widget.isFrontCamera
                            ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
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
                      // Text Overlays
                      ..._textOverlays.map((overlay) => DraggableTextWidget(
                        overlay: overlay,
                        onTap: () => _selectOverlay(overlay),
                        onPositionChanged: (newPosition) {
                          setState(() {
                            overlay.position = newPosition;
                          });
                        },
                        onScaleChanged: (newScale) {
                          setState(() {
                            overlay.scale = newScale;
                          });
                        },
                        onRotationChanged: (newRotation) {
                          setState(() {
                            overlay.rotation = newRotation;
                          });
                        },
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top Action Icons
          Positioned(
            top: MediaQuery.of(context).padding.top + 2,
            left: 10,
            right: 10,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                const Spacer(),
                _buildTopActionIcon(Icons.person_add_alt_1_outlined, () {
                  _openTaggingScreen();
                }),
                _buildTopActionIcon(Icons.text_fields, () {
                  _openTextOverlay();
                }),
                if (_selectedOverlay != null) ...[
                  _buildTopActionIcon(Icons.edit, () {
                    _editSelectedOverlay();
                  }),
                  _buildTopActionIcon(Icons.delete, () {
                    _deleteSelectedOverlay();
                  }),
                ],
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

          // Bottom Action Buttons
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
                  _buildBottomActionButton(
                    label: 'Your story',
                    icon: _isUploading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                    onTap: _isUploading
                        ? () {}
                        : () async {
                      setState(() => _isUploading = true);

                      try {
                        // Capture image with overlays if any text overlays exist
                        File fileToUpload;
                        if (_textOverlays.isNotEmpty) {
                          fileToUpload = await _captureImageWithOverlays();
                        } else {
                          fileToUpload = File(widget.imagePath);
                        }

                        final String? uploadedUrl = await SupabaseService.uploadStoryMedia(fileToUpload);

                        if (uploadedUrl != null) {
                          final storyId = await Provider.of<InstaDataProvider>(context, listen: false)
                              .createStory(uploadedUrl);

                          if (storyId != null && _taggedUsers.isNotEmpty) {
                            await _taggingService.saveTaggedUsersToStory(
                              storyId: storyId,
                              taggedUsers: _taggedUsers,
                            );
                          }

                          Provider.of<InstaDataProvider>(context, listen: false).reloadData();
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        } else {
                          Fluttertoast.showToast(msg: "Failed to upload story media.");
                        }
                      } catch (e) {
                        print('Error uploading story: $e');
                        Fluttertoast.showToast(msg: "Error uploading story.");
                      } finally {
                        setState(() => _isUploading = false);
                      }
                    },
                  ),
                  _buildBottomActionButton(
                    label: 'Close Friends',
                    icon: const Icon(Icons.star_border, color: Colors.greenAccent, size: 20),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Posting to Close Friends!')));
                      Navigator.of(context).pop();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 15.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20),
                        onPressed: _showShareSheet, // Fixed: Now calls the share sheet
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

  Widget _buildTopActionIcon(IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
      ),
    );
  }

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
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// Draggable Text Widget
class DraggableTextWidget extends StatefulWidget {
  final TextOverlay overlay;
  final VoidCallback onTap;
  final Function(Offset) onPositionChanged;
  final Function(double) onScaleChanged;
  final Function(double) onRotationChanged;

  const DraggableTextWidget({
    Key? key,
    required this.overlay,
    required this.onTap,
    required this.onPositionChanged,
    required this.onScaleChanged,
    required this.onRotationChanged,
  }) : super(key: key);

  @override
  State<DraggableTextWidget> createState() => _DraggableTextWidgetState();
}

class _DraggableTextWidgetState extends State<DraggableTextWidget> {
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  TextStyle _getTextStyle() {
    switch (widget.overlay.fontStyle) {
      case 'Modern':
        return TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w300,
          fontSize: 24,
          color: widget.overlay.textColor,
          backgroundColor: widget.overlay.backgroundColor,
        );
      case 'Bold':
        return TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w900,
          fontSize: 24,
          color: widget.overlay.textColor,
          backgroundColor: widget.overlay.backgroundColor,
        );
      case 'Neon':
        return TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w600,
          fontSize: 24,
          color: widget.overlay.textColor,
          backgroundColor: widget.overlay.backgroundColor,
          shadows: [
            Shadow(
              blurRadius: 10.0,
              color: widget.overlay.textColor.withOpacity(0.8),
              offset: const Offset(0, 0),
            ),
          ],
        );
      default: // Classic
        return TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w500,
          fontSize: 24,
          color: widget.overlay.textColor,
          backgroundColor: widget.overlay.backgroundColor,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.overlay.position.dx * 300 - 50, // Convert relative to absolute position
      top: widget.overlay.position.dy * 533 - 50,  // Based on 9:16 aspect ratio
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleStart: (details) {
          _baseScale = widget.overlay.scale;
          _baseRotation = widget.overlay.rotation;
        },
        onScaleUpdate: (details) {
          if (details.pointerCount == 1) {
            // Single finger - pan/drag
            final newPosition = Offset(
              (widget.overlay.position.dx * 300 + details.focalPointDelta.dx) / 300,
              (widget.overlay.position.dy * 533 + details.focalPointDelta.dy) / 533,
            );
            widget.onPositionChanged(newPosition.clamp(Offset.zero, const Offset(1.0, 1.0)));
          } else if (details.pointerCount == 2) {
            // Two fingers - scale and rotate
            final newScale = (_baseScale * details.scale).clamp(0.5, 3.0);
            final newRotation = _baseRotation + details.rotation;

            widget.onScaleChanged(newScale);
            widget.onRotationChanged(newRotation);
          }
        },
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(widget.overlay.scale)
            ..rotateZ(widget.overlay.rotation),
          child: Text(
            widget.overlay.text,
            style: _getTextStyle(),
            textAlign: widget.overlay.alignment,
          ),
        ),
      ),
    );
  }
}
extension OffsetExtension on Offset {
  Offset clamp(Offset min, Offset max) {
    return Offset(
      dx.clamp(min.dx, max.dx),
      dy.clamp(min.dy, max.dy),
    );
  }
}

// Text Overlay Dialog
class TextOverlayDialog extends StatefulWidget {
  final String? initialText;
  final String? initialStyle;
  final Color? initialColor;
  final Color? initialBackgroundColor;
  final Function(String, String, Color, Color) onTextAdded;

  const TextOverlayDialog({
    Key? key,
    this.initialText,
    this.initialStyle,
    this.initialColor,
    this.initialBackgroundColor,
    required this.onTextAdded,
  }) : super(key: key);

  @override
  State<TextOverlayDialog> createState() => _TextOverlayDialogState();
}

class _TextOverlayDialogState extends State<TextOverlayDialog> {
  late TextEditingController _textController;
  String _selectedStyle = 'Classic';
  Color _selectedColor = Colors.white;
  Color _selectedBackgroundColor = Colors.transparent;

  final List<String> _fontStyles = ['Classic', 'Modern', 'Bold', 'Neon'];
  final List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
    _selectedStyle = widget.initialStyle ?? 'Classic';
    _selectedColor = widget.initialColor ?? Colors.white;
    _selectedBackgroundColor = widget.initialBackgroundColor ?? Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Text',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter your text...',
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
              const SizedBox(height: 20),
          
              // Font Style Selection
              const Text('Style', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _fontStyles.map((style) {
                    return GestureDetector(
                      onTap: () => setState(() => _selectedStyle = style),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedStyle == style ? Colors.blue : Colors.grey[800],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(style, style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
          
              // Text Color Selection
              const Text('Text Color', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _colors.map((color) {
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color ? Colors.white : Colors.grey,
                            width: _selectedColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
          
              // Background Color Selection
              const Text('Background', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedBackgroundColor = Colors.transparent),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedBackgroundColor == Colors.transparent ? Colors.white : Colors.grey,
                            width: _selectedBackgroundColor == Colors.transparent ? 3 : 1,
                          ),
                        ),
                        child: const Icon(Icons.not_interested, color: Colors.white, size: 16),
                      ),
                    ),
                    ..._colors.map((color) {
                      return GestureDetector(
                        onTap: () => setState(() => _selectedBackgroundColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedBackgroundColor == color ? Colors.white : Colors.grey,
                              width: _selectedBackgroundColor == color ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 30),
          
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final text = _textController.text.trim();
                      if (text.isNotEmpty) {
                        widget.onTextAdded(text, _selectedStyle, _selectedColor, _selectedBackgroundColor);
                        Navigator.pop(context);
                      }
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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}