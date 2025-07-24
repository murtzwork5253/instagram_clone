import 'package:Instagram/services/auth_service.dart';
import 'package:Instagram/screens/auth/login_page.dart';
import 'package:flutter/material.dart';

class SignUpWithMobile extends StatefulWidget {
  final String userId;

  const SignUpWithMobile({super.key, required this.userId});

  @override
  State<SignUpWithMobile> createState() => _SignUpWithMobileState();
}

class _SignUpWithMobileState extends State<SignUpWithMobile> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController mobileController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addMobilePhone() async {
    final mobile = mobileController.text.trim();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Format phone number with country code (assuming Indian numbers here)
        final formattedPhone = '+91$mobile';

        // 1. Check if phone already exists
        final phoneCheck = await AuthService.client()
            .from('users')
            .select()
            .eq('phone', formattedPhone)
            .maybeSingle();

        if (phoneCheck != null) {
          throw Exception('This phone number is already registered');
        }

        // 2. Update user record
        final response = await AuthService.client()
            .from('users')
            .update({
              'phone': formattedPhone,
            })
            .eq('id', widget.userId)
            .select();

        if (response.isEmpty) {
          throw Exception('Failed to update phone number');
        }

        // // 3. Optional: Send OTP verification
        // await AuthService.client().auth.signInWithOtp(
        //   phone: formattedPhone,
        // );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number added successfully!')),
        );

        // Navigate to next screen or home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
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
    mobileController.dispose();
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
                // Header Text
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 10),
                  child: Text(
                    "Add your mobile number?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),

                // Description
                Padding(
                  padding:
                      const EdgeInsets.only(left: 20.0, right: 50, top: 10),
                  child: Text(
                    "Enter the mobile number on which you can be contacted. No one will see this on your profile.",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),

                // Phone Input Field
                Padding(
                  padding:
                      const EdgeInsets.only(left: 20.0, right: 20, top: 20),
                  child: TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your mobile number';
                      } else if (value.length != 10) {
                        return 'Please enter a valid 10-digit number';
                      } else if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                        return 'Only numbers are allowed';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      prefix: const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Text('+91 | '),
                      ),
                      hintText: "1234567890",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                // Notification Note
                Padding(
                  padding:
                      const EdgeInsets.only(left: 20.0, right: 50, top: 10),
                  child: Text(
                    "You may receive Whatsapp and SMS notifications from us for security and login purposes.",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                  ),
                ),

                // Next Button
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addMobilePhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 56, 83, 250),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Next", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),

                // Skip Button
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 15),
                  child: SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: TextButton(
                      onPressed: () async {
                        await AuthService.client().auth.signOut();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        "Skip",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 56, 83, 250),
                        ),
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
