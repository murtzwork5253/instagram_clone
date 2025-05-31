import 'dart:io';

import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/insta_data_provider.dart';
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

  // Profile image variables
  File? _avatarFile;
  String? _uploadedAvatarUrl;

  // Loading state
  bool _isLoading = true;

  // Track if data was fetched from database
  bool _hasExistingData = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _loadExistingUserData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Fetch existing user data from database
  Future<void> _loadExistingUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await AuthService.client()
          .from('users')
          .select('phone, birthdate, profile_image_url')
          .eq('id', widget.user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _hasExistingData = true;

          // Load phone number
          if (response['phone'] != null && response['phone'].isNotEmpty) {
            String phone = response['phone'].toString();
            // Extract country code and phone number
            _extractPhoneData(phone);
          }

          // Load birth date
          if (response['birthdate'] != null) {
            _birthDate = DateTime.parse(response['birthdate']);
          }

          // Load profile image
          if (response['profile_image_url'] != null &&
              response['profile_image_url'].isNotEmpty) {
            _uploadedAvatarUrl = _getPublicImageUrl(response['profile_image_url']);
          }
        });
      }
    } catch (e) {
      print("❌ Error loading existing user data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Extract country code and phone number from full phone string
  void _extractPhoneData(String fullPhone) {
    // Common country codes to check
    final countryCodes = ['+1', '+91', '+44', '+33', '+49', '+81', '+86', '+61'];

    for (String code in countryCodes) {
      if (fullPhone.startsWith(code)) {
        _countryCode = code;
        _phoneController.text = fullPhone.substring(code.length);
        return;
      }
    }

    // If no country code found, assume it's without country code
    _phoneController.text = fullPhone;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_hasExistingData ? "Update Profile" : "Complete Profile")
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Profile Image Section
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _getProfileImage(),
                      child: _shouldShowCameraIcon()
                          ? const Icon(Icons.camera_alt, color: Colors.white, size: 30)
                          : null,
                    ),
                    // Edit icon overlay
                    if (_uploadedAvatarUrl != null || _avatarFile != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Phone Number Section
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
                    initialSelection: _getInitialCountryFromCode(),
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
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: const OutlineInputBorder(),
                        focusColor: Colors.grey,
                        hintText: '1234567890',
                        helperText: _phoneController.text.isNotEmpty
                            ? 'Current: $_countryCode${_phoneController.text}'
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
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

              // Birth Date Section
              ListTile(
                title: Text(
                  _birthDate == null
                      ? "Select Birth Date"
                      : "Birth Date: ${DateFormat('yyyy-MM-dd').format(_birthDate!)}",
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _birthDate ?? DateTime(2000),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _hasExistingData ? "Update Profile" : "Complete Profile",
                    style: const TextStyle(fontSize: 15),
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
                            builder: (context) => const HomeDashboard()));
                  },
                  child: const Text("Cancel"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get public image URL
  String _getPublicImageUrl(String imageUrl) {
    // Check if it's already a full URL (starts with http/https)
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // If it's just a path, construct the public URL
    // Remove leading slash if present
    String cleanPath = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;

    // If path doesn't start with 'public/', add it
    if (!cleanPath.startsWith('public/')) {
      cleanPath = 'public/$cleanPath';
    }

    // Generate public URL using Supabase storage
    return Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(cleanPath);
  }

  // Helper method to get profile image
  ImageProvider? _getProfileImage() {
    if (_avatarFile != null) {
      return FileImage(_avatarFile!);
    } else if (_uploadedAvatarUrl != null) {
      return NetworkImage(_uploadedAvatarUrl!);
    } else {
      return const AssetImage('assets/avatar_placeholder.png');
    }
  }

  // Helper method to determine if camera icon should be shown
  bool _shouldShowCameraIcon() {
    return _avatarFile == null && _uploadedAvatarUrl == null;
  }

  // Helper method to get initial country selection from country code
  String _getInitialCountryFromCode() {
    switch (_countryCode) {
      case '+1':
        return 'US';
      case '+91':
        return 'IN';
      case '+44':
        return 'GB';
      case '+33':
        return 'FR';
      case '+49':
        return 'DE';
      case '+81':
        return 'JP';
      case '+86':
        return 'CN';
      case '+61':
        return 'AU';
      default:
        return 'US';
    }
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
            print("⚠️ Failed to upload avatar, continuing without profile image");
          }
        }

        print("Saving profile with image URL: $profileImageUrl");

        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_hasExistingData ? "Updating profile..." : "Saving profile...")),
        );

        // Save to Supabase
        await AuthService.client().from('users').upsert({
          'id': widget.user.id,
          'email': widget.email,
          'phone': "${_countryCode}${_phoneController.text}",
          'birthdate': _birthDate!.toIso8601String(),
          'profile_image_url': profileImageUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });

        print("✅ Profile saved successfully");

        // Navigate to home
        if (mounted) {
          final provider = Provider.of<InstaDataProvider>(context, listen: false);
          await provider.refreshFeed();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeDashboard()),
          );
        }
      } catch (e) {
        print("❌ Failed to save profile: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save profile: ${e.toString()}")),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields")),
      );
    }
  }

  Future<String?> _uploadAvatar(File file) async {
    try {
      if (!await file.exists()) {
        print("❌ File does not exist: ${file.path}");
        return null;
      }

      final fileSize = await file.length();
      print("File size: ${fileSize} bytes");

      final fileName =
          '${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}${path_package.extension(file.path)}';

      print("Uploading avatar: $fileName");

      if (Supabase.instance.client.auth.currentSession == null) {
        print("❌ Supabase client is not authenticated");
        return null;
      }

      final bytes = await file.readAsBytes();

      print("Starting upload to Supabase storage...");
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary('public/$fileName', bytes);

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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Uploading image...")),
        );

        final url = await _uploadAvatar(file);

        if (url != null) {
          setState(() {
            _uploadedAvatarUrl = url;
          });

          print("Avatar URL set in state: $_uploadedAvatarUrl");

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Image uploaded successfully")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Failed to upload image - see console for details")),
          );
        }
      }
    } catch (e, stackTrace) {
      print("❌ Error in _pickAvatar: $e");
      print("Stack trace: $stackTrace");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting image: ${e.toString()}")),
      );
    }
  }
}