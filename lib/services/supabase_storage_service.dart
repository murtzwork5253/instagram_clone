import 'dart:typed_data'; // Make sure this is imported
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'insta_data_provider.dart';

class SupabaseStorageService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final _uuid = Uuid();

  static Future<String> uploadImage(
      File imageFile, {
        String folder = 'post-media',
        void Function(double progress)? onProgress,
      }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final fileExt = path.extension(imageFile.path);
    final fileName = '${_uuid.v4()}$fileExt';
    final filePath = '${user.id}/$fileName';

    // 📦 Step 1: Compress the image
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 1080, // adjust resolution as needed
      minHeight: 1080,
      quality: 70, // adjust quality (0-100)
      format: fileExt.toLowerCase() == '.png'
          ? CompressFormat.png
          : CompressFormat.jpeg,
    );

    if (compressedBytes == null) throw Exception('Image compression failed');

    // 👇 Optionally report "fake" progress since compression is instant
    onProgress?.call(0.5);

    // 📤 Step 2: Upload to Supabase
    await _client.storage.from(folder).uploadBinary(
      filePath,
      Uint8List.fromList(compressedBytes),
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );

    onProgress?.call(1.0);

    return _client.storage.from(folder).getPublicUrl(filePath);
  }

  static Future<String> uploadStory(File imageFile) async {
    return uploadImage(imageFile, folder: 'story-media');
  }
}

class PostCreationScreen extends StatefulWidget {
  @override
  _PostCreationScreenState createState() => _PostCreationScreenState();
}

class _PostCreationScreenState extends State<PostCreationScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  File? _imageFile;
  double _uploadProgress = 0.0;
  bool _isLoading = false;

  Future<void> _selectImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo, color: Colors.white),
              title: Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                final picked =
                    await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  setState(() => _imageFile = File(picked.path));
                }
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.white),
              title:
                  Text('Take a Photo', style: TextStyle(color: Colors.white)),
              onTap: () async {
                final picked =
                    await ImagePicker().pickImage(source: ImageSource.camera);
                if (picked != null) {
                  setState(() => _imageFile = File(picked.path));
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final imageUrl = await SupabaseStorageService.uploadImage(
        _imageFile!,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      await Provider.of<InstaDataProvider>(context, listen: false).createPost(
        imageUrl: imageUrl,
        caption: _captionController.text,
        location: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Post'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _isLoading ? null : _createPost,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) ...[
              LinearProgressIndicator(value: _uploadProgress),
              SizedBox(height: 8),
              Text(
                'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 16),
            ],
            GestureDetector(
              onTap: _selectImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : Center(
                        child: Icon(Icons.add_a_photo,
                            size: 50, color: Colors.grey[700]),
                      ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Add location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
