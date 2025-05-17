import 'package:Instagram/screens/auth/auth_service.dart';
import 'package:Instagram/screens/auth/login_page.dart';
import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final String userId;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.userId,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 30;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    // Auto-focus first OTP field
    _focusNodes[0].requestFocus();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_resendCountdown > 0 && mounted) {
        setState(() => _resendCountdown--);
        _startResendCountdown();
      }
    });
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    final otp = _otpControllers.map((c) => c.text).join();

    try {
      final response = await AuthService.client().auth.verifyOTP(
        phone: widget.phone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user == null) throw Exception('Verification failed');

      // Mark phone as verified in users table
      await AuthService.client().from('users').update({
        'phone_verified_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.userId);

      // Navigate to home screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeDashboard()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _resendCountdown = 30;
    });

    try {
      await AuthService.client().auth.signInWithOtp(
        phone: widget.phone,
      );
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isResending = false);
    }
  }

  void _handleOtpInput(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index].unfocus();
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index].unfocus();
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-submit when all fields are filled
    if (_otpControllers.every((c) => c.text.isNotEmpty)) {
      _verifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  "Verify your phone number",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),

              // Description
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text.rich(
                  TextSpan(
                    text: "Enter the 6-digit code sent to ",
                    children: [
                      TextSpan(
                        text: widget.phone,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
              ),

              // OTP Input Fields
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      height: 45,
                      child: TextFormField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (value) => _handleOtpInput(index, value),
                      ),
                    );
                  }),
                ),
              ),

              // Resend OTP Button
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Center(
                  child: TextButton(
                    onPressed: _resendCountdown > 0 || _isResending
                        ? null
                        : _resendOtp,
                    child: Text(
                      _resendCountdown > 0
                          ? 'Resend code in $_resendCountdown'
                          : 'Resend code',
                      style: TextStyle(
                        color: _resendCountdown > 0
                            ? Colors.grey
                            : const Color.fromARGB(255, 56, 83, 250),
                      ),
                    ),
                  ),
                ),
              ),

              // Next Button
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 56, 83, 250),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Verify", style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),

              // Skip Button
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: TextButton(
                    onPressed: () async {
                      await AuthService.client().auth.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
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
    );
  }
}