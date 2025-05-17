import 'package:Instagram/screens/auth/auth_service.dart';
import 'package:Instagram/screens/auth/login_page.dart';
import 'package:Instagram/screens/auth/set_username_screen.dart';
import 'package:flutter/material.dart';

class CreatePassword extends StatefulWidget {
  final String email;

  const CreatePassword({super.key, required this.email});

  @override
  State<CreatePassword> createState() => CreatePasswordState();
}

class CreatePasswordState extends State<CreatePassword> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createPassword() async {
    final password = passwordController.text.trim();

    if (_formKey.currentState!.validate()) {
      if (password.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });

        try {
          final authResponse = await AuthService.client().auth.signUp(
                email: widget.email,
                password: password,
              );

          if (authResponse.user == null) {
            throw Exception('Sign up failed');
          }

          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => UsernameScreen(
                        password: password,
                        email: widget.email,
                        userId: authResponse.user!.id,
                      )));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating password: $e')),
          );
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 10),
                  child: Text(
                    "Create a password",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 50),
                  child: Text(
                    "Create a password with at least 6 letters or numbers. It should be something that others can’t guess.",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20),
                  child: TextFormField(
                    controller: passwordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter a password";
                      } else if (value.length < 6) {
                        return "Password should be at least 6 characters";
                      }
                      return null;
                    },
                    onFieldSubmitted: (value) {
                      FocusScope.of(context).requestFocus(FocusNode());
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                      }
                    },
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Password",
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
                      onPressed: _isLoading ? null : _createPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 56, 83, 250),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Next",
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 464),
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
