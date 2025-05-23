import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class PostProvider with ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  XFile? _image;
  String _caption = '';
  bool _isLoading = false;
  String? _error;

    void _setError(String? value) {
      _error = value;
      notifyListeners();
    }

  XFile? get image => _image;
  String get caption => _caption;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setCaption(String value) {
    _caption = value;
    notifyListeners();
  }

  void pickImage({required bool fromCamera}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );

      if (pickedFile != null) {
        _image = pickedFile;
        notifyListeners();
      } else {
        _setError('No image selected.');
      }
    } catch (e) {
      _setError('Failed to pick image: $e');
    }
  }

  Future<void> uploadPost() async {
    if (_image == null || _caption.isEmpty) {
      _error = 'Image and caption are required.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _error = 'User not authenticated.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final bytes = await _image!.readAsBytes();
      final fileExt = path.extension(_image!.path);
      final fileName = '${const Uuid().v4()}$fileExt';
      final filePath = '${user.id}/$fileName';

      await supabase.storage
          .from('post-media')
          .uploadBinary(filePath, bytes);

      final imageUrl = supabase.storage
          .from('post-media')
          .getPublicUrl(filePath);

      await supabase.from('posts').insert({
        'image_url': imageUrl,
        'caption': _caption,
        'user_id': user.id,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // If the insert operation throws an exception, it will be caught by the outer try-catch block.
      // If it returns successfully, no explicit error check is needed here.
      _image = null;
      _caption = '';
    } catch (e) {
      _error = 'An error occurred: $e';
    }

    _isLoading = false;
    notifyListeners();
  }
}
