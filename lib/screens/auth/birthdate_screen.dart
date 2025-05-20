import 'package:Instagram/screens/auth/signup_with_mobile_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'service/auth_service.dart';

class BirthDateScreen extends StatefulWidget {
  final String email;
  final String username;
  final String userId;

  const BirthDateScreen(
      {super.key,
      required this.email,
      required this.username,
      required this.userId});

  @override
  State<BirthDateScreen> createState() => BirthDateScreenState();
}

class BirthDateScreenState extends State<BirthDateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController birthdateController = TextEditingController();
  bool _isLoading = false;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _completeRegistration() async {
    final birthdate = birthdateController.text.trim();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Store all user data in users table
        await AuthService.client().from('users').upsert({
          'id': widget.userId,
          'email': widget.email,
          'username': widget.username,
          'birthdate': birthdate,
          'created_at': DateTime.now().toIso8601String(),
        });

        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SignUpWithMobile(userId: widget.userId)),
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
    // TODO: implement dispose
    super.dispose();
    birthdateController.dispose();
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
                    "What's your date of birth",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 50),
                  child: Text(
                    "Use your own date of birth, even if this account is for a business, a pet or something else, No one will see this unless you choose to share it.",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20),
                  child: TextFormField(
                    controller: birthdateController,
                    onTap: _selectDate,
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter birthdate";
                      }
                      try {
                        final date = DateTime.parse(value);
                        final age =
                            DateTime.now().difference(date).inDays ~/ 365;
                        if (age < 13) {
                          return "You must be at least 13 years old";
                        }
                      } catch (e) {
                        return "Please enter a valid date (YYYY-MM-DD)";
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
                      hintText: "Birthday",
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
                      onPressed: _isLoading ? null : _completeRegistration,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
