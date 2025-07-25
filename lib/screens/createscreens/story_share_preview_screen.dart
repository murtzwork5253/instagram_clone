import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';

class StorySharePreviewScreen extends StatefulWidget {
  final PostData post;

  const StorySharePreviewScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<StorySharePreviewScreen> createState() => _StorySharePreviewScreenState();
}

class _StorySharePreviewScreenState extends State<StorySharePreviewScreen> {
  final GlobalKey _storyCaptureKey = GlobalKey();
  bool _isUploading = false;

  Future<File?> _captureStoryWidget() async {
    try {
      final boundary = _storyCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName = 'story_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path.join(tempDir.path, fileName));
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      print("Error capturing story widget: $e");
      Fluttertoast.showToast(msg: "Failed to capture story content.");
      return null;
    }
  }

  Future<void> _postStory() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final imageFile = await _captureStoryWidget();
      if (imageFile == null) {
        throw Exception("Failed to prepare story image.");
      }

      final uploadedUrl = await SupabaseService.uploadStoryMedia(imageFile);
      final provider = Provider.of<InstaDataProvider>(context, listen: false);

      await provider.createStory(uploadedUrl, sharedPostId: widget.post.id);

      // Navigate back to home screen after successful post
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } catch (e) {
      print("Error posting story: $e");
      Fluttertoast.showToast(msg: "An error occurred while posting the story.");
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  String _getProfileImageUrl(String? profileImageUrl) {
    if (profileImageUrl == null || profileImageUrl.isEmpty) {
      // Return a default placeholder if the URL is null or empty
      return 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/default_avatar.png';
    }
    if (profileImageUrl.startsWith('http')) {
      return profileImageUrl;
    }
    return 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$profileImageUrl';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The content to be captured as the story
          RepaintBoundary(
            key: _storyCaptureKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image (blurred)
                CachedNetworkImage(
                  imageUrl: widget.post.imageUrl,
                  fit: BoxFit.cover,
                ),
                BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),

                // Post Card
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.black,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Post Header
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: CachedNetworkImageProvider(
                                      _getProfileImageUrl(widget.post.profileImageUrl),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.post.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Post Image
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: CachedNetworkImage(
                                imageUrl: widget.post.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),

          // UI Overlays (buttons, etc.)
          SafeArea(
            child: Column(
              children: [
                // Top bar with close button
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Bottom bar with "Post" button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: GestureDetector(
                    onTap: _postStory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                          : const Text(
                        'Post to Your Story',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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