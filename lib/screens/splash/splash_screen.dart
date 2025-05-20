import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Instagram/screens/auth/service/auth_service.dart';
import 'package:Instagram/screens/auth/login_page.dart';
import 'package:Instagram/screens/auth/profile_completion_screen.dart';
import 'package:Instagram/screens/homescreen/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Add a small delay for splash screen visibility
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // Check if there's an active session
      final session = AuthService.client().auth.currentSession;

      if (session == null) {
        _navigateToLogin();
        return;
      }

      // Session exists, check if user profile is complete
      final user = session.user;
      await _verifyUserProfileCompletion(user);
    } catch (e) {
      debugPrint('Session check error: $e');
      _navigateToLogin();
    }
  }

  Future<void> _verifyUserProfileCompletion(User user) async {
    try {
      // Check if user has completed their profile
      final profileData = await AuthService.client()
          .from('users')
          .select('phone, birthdate, username, email')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profileData == null || profileData['phone'] == null) {
        // Profile incomplete - redirect to profile completion
        String? email = user.email ?? profileData?['email'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileCompletionScreen(
              user: user,
              email: email ?? '',
            ),
          ),
        );
      } else {
        // Profile complete - redirect to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeDashboard()),
        );
      }
    } catch (e) {
      debugPrint('Profile verification error: $e');
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/logo.png",
              width: 80,
              height: 80,
            ),
          ],
        ),
      ),
    );
  }
}
