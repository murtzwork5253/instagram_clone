import 'package:Instagram/screens/auth/service/auth_service.dart';
import 'package:Instagram/screens/auth/birthdate_screen.dart';
import 'package:flutter/material.dart';

class UsernameScreen extends StatefulWidget {
  final String password;
  final String email;
  final String userId;

  const UsernameScreen(
      {super.key,
      required this.password,
      required this.email,
      required this.userId});

  @override
  State<UsernameScreen> createState() => UsernameScreenState();
}

class UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _addBirthdate() async {
    final username = usernameController.text.trim();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final client = AuthService.client();
        final user = client.auth.currentUser;

        if (user == null) {
          throw Exception("User not authenticated.");
        }

        // 1. Check username availability
        final usernameCheck = await client
            .from('users')
            .select()
            .eq('username', username)
            .maybeSingle();

        if (usernameCheck != null) {
          throw Exception('Username already taken. Try another.');
        }

        // 2. Store user data in users table (RLS-safe)
        await client.from('users').upsert({
          'id': user.id, // Supabase Auth UID
          'email': user.email,
          'username': username,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. Navigate to BirthDateScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BirthDateScreen(
              userId: user.id,
              email: user.email ?? '',
              username: username,
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 20, top: 10),
                  child: Text(
                    "Create a username",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.only(left: 20.0, right: 50),
                  child: Text("Add a username. You can change this at any time."),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20),
                  child: TextFormField(
                    controller: usernameController,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Username cannot be empty";
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: "Username",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addBirthdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 56, 83, 250),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                          : const Text("Next", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
