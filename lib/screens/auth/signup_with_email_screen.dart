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
  bool _isValidatingEmail = false;

  // List of allowed legitimate email providers
  final Set<String> _allowedDomains = {
    // Google
    'gmail.com',
    'googlemail.com',

    // Microsoft
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',

    // Yahoo
    'yahoo.com',
    'yahoo.co.uk',
    'yahoo.co.in',
    'yahoo.ca',
    'yahoo.com.au',
    'ymail.com',
    'rocketmail.com',

    // Apple
    'icloud.com',
    'me.com',
    'mac.com',

    // Other major providers
    'protonmail.com',
    'proton.me',
    'aol.com',
    'zoho.com',
    'mail.com',
    'gmx.com',
    'tutanota.com',
    'fastmail.com',
    'yandex.com',
    'mail.ru',
    'qq.com',
    '163.com',
    '126.com',
    'sina.com',
    'rediffmail.com',

    // Educational domains (common ones)
    'edu',
    'ac.uk',
    'edu.au',
    'edu.in',

    // Add more legitimate providers as needed
  };

  // Validate email domain against whitelist
  bool _validateEmailDomain(String email) {
    try {
      final domain = email.split('@').last.toLowerCase();

      // Check if domain is in allowed list
      if (_allowedDomains.contains(domain)) {
        return true;
      }

      // Check for educational domains (ends with .edu, .ac.uk, etc.)
      if (domain.endsWith('.edu') ||
          domain.endsWith('.ac.uk') ||
          domain.endsWith('.edu.au') ||
          domain.endsWith('.edu.in') ||
          domain.endsWith('.ac.in')) {
        return true;
      }

      return false;
    } catch (e) {
      print('Email domain validation error: $e');
      return false;
    }
  }

  // Basic email format validation
  bool _isValidEmailFormat(String email) {
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegExp.hasMatch(email);
  }

  void _goToPasswordScreen() async {
    final email = emailController.text.trim();

    if (_formKey.currentState!.validate()) {
      if (email.isNotEmpty && _isValidEmailFormat(email)) {
        setState(() {
          _isValidatingEmail = true;
        });

        try {
          // First, validate email domain against whitelist
          final isValidDomain = _validateEmailDomain(email);

          if (!isValidDomain) {
            setState(() {
              _isValidatingEmail = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please use an email from a recognized provider (Gmail, Yahoo, Outlook, etc.).'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Query the Supabase 'users' table for the given email
          final response = await Supabase.instance.client
              .from('users')
              .select()
              .eq('email', email)
              .maybeSingle(); // returns null if not found

          setState(() {
            _isValidatingEmail = false;
          });

          if (response != null) {
            // Email already exists
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('This email is already registered. Please sign in.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            // Email not found — proceed to password creation screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreatePassword(email: email)),
            );
          }
        } catch (e) {
          setState(() {
            _isValidatingEmail = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error validating email: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid email address'),
            backgroundColor: Colors.red,
          ),
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
                      } else if (!_isValidEmailFormat(value)) {
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
                      onPressed: _isValidatingEmail ? null : () {
                        _goToPasswordScreen();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 56, 83, 250),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isValidatingEmail
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text("Next", style: TextStyle(fontSize: 16)),
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