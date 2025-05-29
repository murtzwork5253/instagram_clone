import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../services/insta_data_provider.dart';
import '../auth/login_page.dart';
import '../auth/service/auth_service.dart';

class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});

  State<ProfileMenuScreen> createState() => ProfileMenuScreenState();
}

class ProfileMenuScreenState extends State<ProfileMenuScreen> {


  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
    '1051202779186-kqac9ms2803rllegshdu2d3n6bjff23h.apps.googleusercontent.com', // Add this for better security
  );

  // Enhanced logout function
  Future<void> _logout() async {
    try {
      // setState(() => _isLoading = true);

      // 1. Sign out from Google
      await _googleSignIn.signOut();

      // 2. Sign out from Supabase
      await AuthService.client().auth.signOut();

      // 3. Clear any cached credentials
      // await _googleSignIn.disconnect();

      Provider.of<InstaDataProvider>(context, listen: false).reset();

      // Optional: Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // SafeArea is often handled by Scaffold internally
      backgroundColor: Colors.black, // Set scaffold background to black
      appBar: AppBar(
        backgroundColor: Colors.black, // AppBar background black
        foregroundColor: Colors.white, // Icons and text color white
        elevation: 0, // No shadow
        title: const Text(
          "Settings and activity",
          style: TextStyle(
            fontWeight: FontWeight.bold, // Make title bold
          ),
        ),
        leading: IconButton( // Add a leading back button
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Pop the current screen off the stack
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMenuItem(Icons.account_circle_outlined, "Account", () {
              print("Account tapped!");
            },true),
            const Divider(color: Colors.white, height: 20, thickness: 0.4,indent: 6,endIndent: 6,),
            // Section 1: Top options
            _buildMenuItem(Icons.person_add_alt_1_outlined, "Follow and invite friends", () {
              print("Follow and invite friends tapped!");
            }, true),
            _buildMenuItem(Icons.notifications_none, "Notifications", () {
              print("Notifications tapped!");
            },true),
            _buildMenuItem(Icons.lock_outline, "Privacy", () {
              print("Privacy tapped!");
            },true),
            _buildMenuItem(Icons.supervised_user_circle_outlined, "Supervision", () {
              print("Supervision tapped!");
            },true),
            _buildMenuItem(Icons.security, "Security", () {
              print("Security tapped!");
            },true),
            _buildMenuItem(Icons.credit_card, "Payments", () {
              print("Payments tapped!");
            },true),
            _buildMenuItem(Icons.add_alert_outlined, "Ads", () {
              print("Ads tapped!");
            },true),
            _buildMenuItem(Icons.language_outlined, "Language", () {
              print("Language tapped!");
            },true),
            _buildMenuItem(Icons.help_outline, "Help", () {
              print("Help tapped!");
            },true),
            _buildMenuItem(Icons.info_outline, "About", () {
              print("About tapped!");
            },true),
            const Divider(color: Colors.white, height: 20, thickness: 0.2), // Divider
            // Section 2: Login and Logout
            _buildMenuItem(Icons.logout, "Log out", () {
              // print("Log out tapped!");
              _logout();
            }, false),
            // Add more menu items as needed
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, bool isTrailingIcon) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 28),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: isTrailingIcon ? Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16) : null, // Optional: right arrow
      onTap: onTap,
    );
  }
}