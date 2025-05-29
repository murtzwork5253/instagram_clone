// File: edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final supabase = Supabase.instance.client;
  // Removed GlobalKey<NavigatorState> as it's typically not needed here and can cause context issues.
  // The 'context' property of a State object is usually sufficient.
  String? avatarUrl;

  // Make profile nullable and initially null, so it's not 'late'.
  Map<String, dynamic>? profile;

  // Add a loading state to manage UI display during data fetching.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // Fetch the profile data.
      profile = await supabase.from('users').select().eq('id', userId).single();

      // Ensure profile is not null before trying to access its keys.
      if (profile != null) {
        if (profile!['profile_image_url'] != null) {
          final String imageUrl = profile!['profile_image_url'];
          avatarUrl = imageUrl.startsWith('http')
              ? imageUrl
              : supabase.storage.from('avatars').getPublicUrl(imageUrl);
        }

        // Populate the text controllers with the loaded data.
        _nameController.text = profile!['full_name'] ?? '';
        _bioController.text = profile!['bio'] ?? '';
        _websiteController.text = profile!['website'] ?? '';
      }
    } catch (e) {
      // Print any errors during profile loading for debugging.
      print("Error loading profile data: $e");
      // Consider showing a user-friendly message here, e.g., a SnackBar.
    } finally {
      // No matter if success or error, set loading to false and rebuild the UI.
      // Check if the widget is still mounted before calling setState to prevent errors.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('users').update({
      'full_name': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'website': _websiteController.text.trim(),
    }).eq('id', userId);

    Navigator.pop(context, true); // trigger refresh on profile screen
  }

  @override
  Widget build(BuildContext context) {
    // If data is still loading, show a progress indicator.
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // If loading is complete but profile data is null (e.g., user not found or error),
    // show a message instead of trying to build the form.
    if (profile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Text('Failed to load profile data.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    // Now that we're sure profile data is loaded and not null, build the actual UI.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title:
        const Text("Edit Profile", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveProfile,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Pass the nullable profile to _buildAvatarSection, but then handle null inside it.
            _buildAvatarSection(avatarUrl, profile!),
            const SizedBox(height: 16),
            const Text("Change profile picture", style: TextStyle(color: Colors.blue, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Full Name",
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Bio",
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _websiteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Website",
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImagePicker(String? userId) async {
    print('_showImagePicker called with userId: $userId');
    if (userId == null) {
      _showErrorSnackBar('Error: User not logged in');
      return;
    }

    final BuildContext context = this.context;

    try {
      List<Permission> permissionsToRequest = [
        Permission.camera,
        Permission.storage,
        Permission.photos,
      ];

      final statuses = await permissionsToRequest.request();
      final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final storageAccess =
          (statuses[Permission.storage]?.isGranted ?? false) ||
              (statuses[Permission.photos]?.isGranted ?? false);

      if (!cameraGranted || !storageAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
              Text('Please grant required permissions to update picture'),
            ),
          );
        }
        return;
      }
    } catch (e) {
      _showErrorSnackBar('Please grant camera and storage access in settings');
      return;
    }

    try {
      final picker = ImagePicker();
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.grey[900],
        builder: (BuildContext ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Update Profile Picture',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.blue),
                  title: const Text("Photo Gallery"),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text("Camera"),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      );

      if (source != null && mounted) {
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 75,
          maxWidth: 800,
        );

        if (image != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );

          try {
            final bytes = await image.readAsBytes();
            final fileName =
                'public/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

            await Supabase.instance.client.storage.from('avatars').uploadBinary(
                fileName, bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'));

            Navigator.of(context).pop(); // close loading

            await Supabase.instance.client
                .from('users')
                .update({'profile_image_url': fileName}).eq('id', userId);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile image updated')),
            );

            // Trigger a rebuild to reflect the new avatar URL, which will cause _loadProfileData to re-run
            // or you can manually update the avatarUrl and call setState.
            // For now, setState will re-run build. To refresh _loadProfileData, you'd need to call it again.
            // Let's call _loadProfileData again to ensure avatarUrl is correctly updated from Supabase.
            _loadProfileData();
          } catch (e) {
            if (mounted) Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading image: $e')),
            );
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    // Removed navigatorKey.currentContext usage as it's often problematic and context is usually sufficient.
    // If you need to show snackbars outside of build methods and outside of a direct context chain,
    // consider using a global scaffold messenger key or an overlay entry.
  }

  Widget _buildAvatarSection(String? avatarUrl, Map<String, dynamic> profile) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return GestureDetector(
      onTap: () {
        if (userId != null) {
          _showImagePicker(userId);
        } else {
          // Changed to use the current context's ScaffoldMessenger
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to update your profile picture'),
            ),
          );
        }
      },
      child: Stack(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.grey[800],
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, color: Colors.white, size: 40)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child:
              const Icon(Icons.add_a_photo, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}