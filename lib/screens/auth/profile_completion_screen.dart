import 'dart:io';

import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'service/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_package;

class ProfileCompletionScreen extends StatefulWidget {
  final User user;
  final String email;

  const ProfileCompletionScreen(
      {required this.user, required this.email, super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _phoneController;
  DateTime? _birthDate;
  String _countryCode = '+1';

  // 👉 Add these here
  File? _avatarFile;
  String? _uploadedAvatarUrl; // Default country code (e.g., US)

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _avatarFile != null
                      ? FileImage(_avatarFile!)
                      : (_uploadedAvatarUrl != null
                          ? NetworkImage(_uploadedAvatarUrl!) as ImageProvider
                          : const AssetImage('assets/avatar_placeholder.png')),
                  child: _avatarFile == null && _uploadedAvatarUrl == null
                      ? const Icon(Icons.camera_alt,
                          color: Colors.white, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CountryCodePicker(
                    onChanged: (country) {
                      setState(() {
                        _countryCode = country.dialCode ?? '+1';
                      });
                    },
                    dialogBackgroundColor: Colors.black,
                    barrierColor: Colors.black,
                    initialSelection: 'US',
                    favorite: ['+1', '+91'],
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: false,
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        focusColor: Colors.grey,
                        hintText: '1234567890',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        // Validate phone number without country code
                        if (!RegExp(r'^[0-9]{6,15}$').hasMatch(value)) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(
                  _birthDate == null
                      ? "Select Birth Date"
                      : "Birth Date: ${DateFormat('yyyy-MM-dd').format(_birthDate!)}",
                  style: TextStyle(color: Colors.white),
                ),
                trailing: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _birthDate = date);
                  }
                },
                tileColor: Colors.grey[900],
                textColor: Colors.white,
              ),
              const SizedBox(height: 50),
              // Submit Button
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: _submitProfile,
                  child: const Text(
                    "Complete Profile",
                    style: TextStyle(fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Cancel Button
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HomeDashboard()));
                  },
                  child: const Text(
                    "Cancel",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitProfile() async {
    if (_formKey.currentState!.validate() && _birthDate != null) {
      try {
        String? profileImageUrl = _uploadedAvatarUrl;

        // If we have a selected file but no URL yet, try to upload it now
        if (_avatarFile != null && profileImageUrl == null) {
          print("Avatar file selected but URL is null, uploading now...");
          profileImageUrl = await _uploadAvatar(_avatarFile!);

          if (profileImageUrl != null) {
            setState(() {
              _uploadedAvatarUrl = profileImageUrl;
            });
          } else {
            print(
                "⚠️ Failed to upload avatar, continuing without profile image");
          }
        }

        print("Saving profile with image URL: $profileImageUrl");

        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saving profile...")),
        );

        // Save to Supabase
        final response = await AuthService.client().from('users').upsert({
          'id': widget.user.id,
          'email': widget.email,
          'phone': "${_countryCode}${_phoneController.text}",
          'birthdate': _birthDate!.toIso8601String(),
          'profile_image_url': profileImageUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });

        print("Profile save response: $response");
        print("✅ Profile saved successfully");

        // Navigate to home
        if (mounted) {
          // Check if the widget is still mounted
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeDashboard()),
          );
        }
      } catch (e) {
        print("❌ Failed to save profile: $e");
        // Show error message to the user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save profile: ${e.toString()}")),
          );
        }
      }
    } else {
      // Show validation message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields")),
      );
    }
  }

  Future<String?> _uploadAvatar(File file) async {
    try {
      // Check if file exists and is readable
      if (!await file.exists()) {
        print("❌ File does not exist: ${file.path}");
        return null;
      }

      final fileSize = await file.length();
      print("File size: ${fileSize} bytes");

      final fileName =
          '${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}${path_package.extension(file.path)}';

      print("Uploading avatar: $fileName");
      print("File path: ${file.path}");

      // Check if Supabase client is initialized
      if (Supabase.instance.client.auth.currentSession == null) {
        print("❌ Supabase client is not authenticated");
        return null;
      }

      // Use ByteData for upload instead of File
      final bytes = await file.readAsBytes();

      // Upload file to 'avatar' bucket
      print("Starting upload to Supabase storage...");
      final response = await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary('public/$fileName', bytes);

      print("Upload response: $response");

      // Get the public URL for the uploaded file
      final avatarUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl('public/$fileName');

      print("✅ Avatar uploaded successfully, URL: $avatarUrl");

      return avatarUrl;
    } catch (e, stackTrace) {
      print("❌ Upload failed: $e");
      print("Stack trace: $stackTrace");
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() {
          _avatarFile = file;
        });

        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Uploading image...")),
        );

        // Upload the avatar and get the URL
        final url = await _uploadAvatar(file);

        if (url != null) {
          setState(() {
            _uploadedAvatarUrl = url;
          });

          print("Avatar URL set in state: $_uploadedAvatarUrl");

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Image uploaded successfully")),
          );
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("Failed to upload image - see console for details")),
          );
        }
      }
    } catch (e, stackTrace) {
      print("❌ Error in _pickAvatar: $e");
      print("Stack trace: $stackTrace");

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting image: ${e.toString()}")),
      );
    }
  }
}
