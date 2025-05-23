import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_storage_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  @override
  Widget build(BuildContext context) {
    return _buildCreateScreen();
  }

  Widget _buildCreateScreen() {
    final captionController = TextEditingController();
    final locationController = TextEditingController();
    final picker = ImagePicker();

    File? selectedImage;
    bool isUploading = false;
    double uploadProgress = 0.0;

    return StatefulBuilder(
      builder: (context, setState) {
        Future<void> _showImageSourceSheet() async {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.grey[900],
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.photo, color: Colors.white),
                    title:
                        Text('Gallery', style: TextStyle(color: Colors.white)),
                    onTap: () async {
                      final picked =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        setState(() {
                          selectedImage = File(picked.path);
                        });
                      }
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.camera_alt, color: Colors.white),
                    title:
                        Text('Camera', style: TextStyle(color: Colors.white)),
                    onTap: () async {
                      final picked =
                          await picker.pickImage(source: ImageSource.camera);
                      if (picked != null) {
                        setState(() {
                          selectedImage = File(picked.path);
                        });
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          );
        }

        Future<void> _submitPost() async {
          if (selectedImage == null || captionController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Please select an image and enter a caption')),
            );
            return;
          }

          setState(() {
            isUploading = true;
            uploadProgress = 0.0;
          });

          try {
            final imageUrl = await SupabaseStorageService.uploadImage(
              selectedImage!,
              onProgress: (progress) {
                setState(() {
                  uploadProgress = progress;
                });
              },
            );

            await Provider.of<InstaDataProvider>(context, listen: false)
                .createPost(
              imageUrl: imageUrl,
              caption: captionController.text,
              location: locationController.text,
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: ${e.toString()}')),
            );
          } finally {
            setState(() => isUploading = false);
          }
        }

        return SafeArea(
          child: Scaffold(
            appBar: AppBar(
              title: Text("Create Post", style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.black,
            ),
            backgroundColor: Colors.black,
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _showImageSourceSheet,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: selectedImage != null
                            ? Image.file(selectedImage!, fit: BoxFit.cover)
                            : Center(
                                child: Text("Tap to select image",
                                    style: TextStyle(color: Colors.white)),
                              ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: captionController,
                      maxLines: 3,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Caption",
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue)),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: locationController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Location (optional)",
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue)),
                      ),
                    ),
                    SizedBox(height: 20),
                    if (isUploading) ...[
                      LinearProgressIndicator(value: uploadProgress),
                      SizedBox(height: 8),
                      Text(
                          "Uploading... ${(uploadProgress * 100).toStringAsFixed(0)}%",
                          style: TextStyle(color: Colors.white70)),
                    ],
                    ElevatedButton(
                      onPressed: isUploading ? null : _submitPost,
                      child: Text("Post"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
