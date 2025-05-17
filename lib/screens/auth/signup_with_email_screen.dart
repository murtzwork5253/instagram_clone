import 'package:Instagram/screens/auth/create_password_screen.dart';
import 'package:Instagram/screens/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpWithEmail extends StatefulWidget {
  const SignUpWithEmail({super.key});

  @override
  State<StatefulWidget> createState() => SignUpWithEmailState();
}

class SignUpWithEmailState extends State<StatefulWidget> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();

  void _goToPasswordScreen() async {
    final email = emailController.text.trim();

    if (_formKey.currentState!.validate()) {
      if (email.isNotEmpty && email.contains('@')) {
        try {
          // Query the Supabase 'users' table for the given email
          final response = await Supabase.instance.client
              .from('users')
              .select()
              .eq('email', email)
              .maybeSingle(); // returns null if not found

          if (response != null) {
            // Email already exists
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'This email is already registered. Please sign in.')),
            );
          } else {
            // Email not found — proceed to password creation screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreatePassword(email: email)),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error checking email: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid email address')),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 10),
                  child: Text(
                    "What's your email address?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 50),
                  child: Text(
                    "Enter the email address on which you can be contacted. No one will see this on your profile.",
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20),
                  child: TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email address';
                      } else if (!value.contains('@') ||
                          !value.contains('.') ||
                          !value.contains('com')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    onFieldSubmitted: (value) {
                      FocusScope.of(context).requestFocus(FocusNode());
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: "Email address",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  height: 45,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: ElevatedButton(
                      onPressed: () {
                        _goToPasswordScreen();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 56, 83, 250),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Next", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                SizedBox(height: 478),
                Container(
                  width: double.infinity,
                  height: 45,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      alignment: Alignment.center,
                    ),
                    clipBehavior: Clip.hardEdge,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text(
                      "I already have an account",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
