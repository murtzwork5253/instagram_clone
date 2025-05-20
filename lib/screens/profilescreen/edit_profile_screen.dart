import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final userId = supabase.auth.currentUser!.id;
    final profile =
        await supabase.from('users').select().eq('id', userId).single();

    _nameController.text = profile['full_name'] ?? '';
    _bioController.text = profile['bio'] ?? '';
    _websiteController.text = profile['website'] ?? '';
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
}
