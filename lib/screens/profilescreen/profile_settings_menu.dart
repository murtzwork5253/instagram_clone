// profile_settings_menu.dart
import 'package:Instagram/screens/saved-psots/saved_post_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;

import '../../l10n/app_localizations.dart';
import '../../providers/language_provider.dart';
import '../../services/insta_data_provider.dart';
import '../auth/login_page.dart';
import '../auth/password_change_screen.dart';
import '../auth/service/auth_service.dart';
import '../profilescreen/blocked_users_screen.dart';

// Import all the new screens
// import 'screens/account_screen.dart';
// import 'screens/follow_invite_screen.dart';
// import 'screens/notifications_screen.dart';
// import 'screens/privacy_screen.dart';
// import 'screens/supervision_screen.dart';
// import 'screens/security_screen.dart';
// import 'screens/payments_screen.dart';
// import 'screens/ads_screen.dart';
// import 'screens/language_screen.dart';
// import 'screens/help_screen.dart';
// import 'screens/about_screen.dart';

class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});

  @override
  State<ProfileMenuScreen> createState() => ProfileMenuScreenState();
}

class ProfileMenuScreenState extends State<ProfileMenuScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
    '1051202779186-kqac9ms2803rllegshdu2d3n6bjff23h.apps.googleusercontent.com',
  );

  // Enhanced logout function
  Future<void> _logout() async {
    try {
      // Show confirmation dialog
      bool shouldLogout = await _showLogoutConfirmation();
      if (!shouldLogout) return;

      // 1. Sign out from Google
      await _googleSignIn.signOut();

      // 2. Sign out from Supabase
      await AuthService.client().auth.signOut();

      // 3. Reset provider data
      Provider.of<InstaDataProvider>(context, listen: false).reset();

      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showLogoutConfirmation() async {
    final loc = AppLocalizations.of(context)!;
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(loc.logout, style: const TextStyle(color: Colors.white)),
          content: Text(
            loc.logoutConfirmation,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(loc.cancel, style: const TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(loc.logout, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          loc.settings,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMenuItem(
              Icons.account_circle_outlined,
              loc.account,
                  () => _navigateToScreen(const AccountScreen()),
              true,
            ),
            const Divider(
              color: Colors.white,
              height: 20,
              thickness: 0.4,
              indent: 6,
              endIndent: 6,
            ),

            _buildMenuItem(
              OIcons.Iconsax.save_2_bold,
              loc.savedPosts,
                  () => _navigateToScreen(SavedPostsScreen()),
              false,
            ),
            // Main Settings Section
            _buildMenuItem(
              Icons.person_add_alt_1_outlined,
              loc.followAndInvite,
                  () => _navigateToScreen(const FollowInviteScreen()),
              true,
            ),
            _buildMenuItem(
              Icons.notifications_none,
              loc.notifications,
                  () => _navigateToScreen(const NotificationsScreen()),
              true,
            ),
            _buildMenuItem(
              Icons.lock_outline,
              loc.privacy,
                  () => _navigateToScreen(const PrivacyScreen()),
              true,
            ),
            _buildMenuItem(
              Icons.supervised_user_circle_outlined,
              loc.supervision,
                  () => _navigateToScreen(const SupervisionScreen()),
              true,
            ),
            _buildMenuItem(
              Icons.security,
              loc.security,
                  () => _navigateToScreen(const SecurityScreen()),
              true,
            ),
            _buildMenuItem(
              Icons.credit_card,
              loc.payments,
                  () => _navigateToScreen(const PaymentsScreen()),
              true,
            ),
            _buildMenuItem(
              Icons.add_alert_outlined,
              loc.ads,
                  () => _navigateToScreen(const AdsScreen()),
              true,
            ),
            _buildMenuItem(
              Icons.language_outlined,
              loc.language,
                  () => _navigateToScreen(const LanguageScreen()),
              true,
            ),
            _buildMenuItem(
              Icons.help_outline,
              loc.help,
                  () => _navigateToScreen(const HelpScreen()),
              true,
            ),
            _buildMenuItem(
              Icons.info_outline,
              loc.about,
                  () => _navigateToScreen(const AboutScreen()),
              true,
            ),

            const Divider(color: Colors.white, height: 20, thickness: 0.2),

            // Logout Section
            _buildMenuItem(
              Icons.logout,
              loc.logout,
              _logout,
              false,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      IconData icon,
      String title,
      VoidCallback onTap,
      bool isTrailingIcon,
      ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 28),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: isTrailingIcon
          ? const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16)
          : null,
      onTap: onTap,
    );
  }
}

// ==================== INDIVIDUAL SCREENS ====================

// screens/account_screen.dart
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with dummy data - replace with actual user data
    _usernameController.text = "john_doe";
    _emailController.text = "john.doe@example.com";
    _bioController.text = "Photography enthusiast 📸";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Account'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture Section
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[800],
                    child: const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      // Handle profile picture change
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Change profile picture')),
                      );
                    },
                    child: const Text('Change Profile Photo'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Account Information
            _buildTextField('Username', _usernameController),
            const SizedBox(height: 20),
            _buildTextField('Email', _emailController),
            const SizedBox(height: 20),
            _buildTextField('Bio', _bioController, maxLines: 3),

            const SizedBox(height: 30),

            // Account Options
            _buildAccountOption('Personal Information', Icons.person_outline),
            _buildAccountOption('Professional Dashboard', Icons.dashboard),
            _buildAccountOption('Account Status', Icons.info_outline),
            _buildAccountOption('Download Your Data', Icons.download),
            _buildAccountOption('Delete Account', Icons.delete_outline, isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountOption(String title, IconData icon, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.white,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
          fontSize: 16,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
      onTap: () {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('$title tapped')),
        // );
      },
    );
  }
}

// screens/notifications_screen.dart
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _likesEnabled = true;
  bool _commentsEnabled = true;
  bool _followsEnabled = true;
  bool _messagesEnabled = true;
  bool _liveVideosEnabled = false;
  bool _emailNotifications = true;
  bool _pushNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Notifications'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Push Notifications',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildNotificationSwitch('Likes', _likesEnabled, (value) {
              setState(() => _likesEnabled = value);
            }),
            _buildNotificationSwitch('Comments', _commentsEnabled, (value) {
              setState(() => _commentsEnabled = value);
            }),
            _buildNotificationSwitch('New Followers', _followsEnabled, (value) {
              setState(() => _followsEnabled = value);
            }),
            _buildNotificationSwitch('Direct Messages', _messagesEnabled, (value) {
              setState(() => _messagesEnabled = value);
            }),
            _buildNotificationSwitch('Live Videos', _liveVideosEnabled, (value) {
              setState(() => _liveVideosEnabled = value);
            }),

            const Divider(color: Colors.grey, height: 40),

            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'General Settings',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildNotificationSwitch('Email Notifications', _emailNotifications, (value) {
              setState(() => _emailNotifications = value);
            }),
            _buildNotificationSwitch('Push Notifications', _pushNotifications, (value) {
              setState(() => _pushNotifications = value);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue,
      secondary: const Icon(Icons.notifications, color: Colors.white),
    );
  }
}

// screens/privacy_screen.dart
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _isPrivateAccount = false;
  String _storyVisibility = 'Everyone';
  bool _allowTagging = true;
  bool _showActivity = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Privacy'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Private Account', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Only approved followers can see your posts',
                style: TextStyle(color: Colors.grey),
              ),
              value: _isPrivateAccount,
              onChanged: (value) => setState(() => _isPrivateAccount = value),
              activeColor: Colors.blue,
            ),

            ListTile(
              title: const Text('Story Visibility', style: TextStyle(color: Colors.white)),
              subtitle: Text(_storyVisibility, style: const TextStyle(color: Colors.grey)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              onTap: () => _showStoryVisibilityOptions(),
            ),

            SwitchListTile(
              title: const Text('Allow Tagging', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Let others tag you in their posts',
                style: TextStyle(color: Colors.grey),
              ),
              value: _allowTagging,
              onChanged: (value) => setState(() => _allowTagging = value),
              activeColor: Colors.blue,
            ),

            SwitchListTile(
              title: const Text('Show Activity Status', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Let others see when you were last active',
                style: TextStyle(color: Colors.grey),
              ),
              value: _showActivity,
              onChanged: (value) => setState(() => _showActivity = value),
              activeColor: Colors.blue,
            ),

            const Divider(color: Colors.grey),

            ListTile(
              leading: const Icon(Icons.block, color: Colors.white),
              title: const Text('Blocked Accounts', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BlockedUsersScreen(),
                  ),
                );
              },
            ),
            _buildPrivacyOption('Muted Accounts', Icons.volume_off),
            _buildPrivacyOption('Hidden Words', Icons.visibility_off),
            _buildPrivacyOption('Data Download', Icons.download),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
      onTap: () {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('$title tapped')),
        // );
      },
    );
  }

  void _showStoryVisibilityOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Story Visibility',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...['Everyone', 'Followers', 'Close Friends'].map((option) {
              return ListTile(
                title: Text(option, style: const TextStyle(color: Colors.white)),
                trailing: _storyVisibility == option
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _storyVisibility = option);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

// screens/security_screen.dart
// Updated security_screen.dart section
// Add this import at the top of your profile_settings_menu.dart file:
// import 'password_change_screen.dart';

// Replace the existing SecurityScreen class with this updated version:
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Security'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSecurityOption(
            context,
            'Password',
            Icons.lock_outline,
            'Change your password',
                () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PasswordChangeScreen()),
            ),
          ),
          _buildSecurityOption(
            context,
            'Two-Factor Authentication',
            Icons.security,
            'Add extra security',
                () => _showComingSoon(context, 'Two-Factor Authentication'),
          ),
          _buildSecurityOption(
            context,
            'Login Activity',
            Icons.history,
            'See where you\'re logged in',
                () => _showComingSoon(context, 'Login Activity'),
          ),
          _buildSecurityOption(
            context,
            'Apps and Websites',
            Icons.apps,
            'Manage connected apps',
                () => _showComingSoon(context, 'Apps and Websites'),
          ),
          _buildSecurityOption(
            context,
            'Download Data',
            Icons.download,
            'Get a copy of your data',
                () => _showComingSoon(context, 'Download Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityOption(
      BuildContext context,
      String title,
      IconData icon,
      String subtitle,
      VoidCallback onTap,
      ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 28),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
      onTap: onTap,
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature - Coming Soon')),
    );
  }
}

// Add more screens with similar patterns...
// For brevity, I'll provide a few more essential screens:

// screens/language_screen.dart
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final Map<String, String> _languages = {
    'en': 'English',
    'es': 'Español',
    'gu': 'Gujarati',
    // 'fr': 'Français',
    // 'de': 'Deutsch',
    // 'it': 'Italiano',
    // 'pt': 'Português',
    // 'ja': '日本語',
    // 'ko': '한국어',
    // 'zh': '中文',
    // 'hi': 'हिन्दी'
  };

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLocale = languageProvider.currentLocale.languageCode;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(AppLocalizations.of(context)!.language),
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final languageCode = _languages.keys.elementAt(index);
          final languageName = _languages[languageCode];
          return ListTile(
            title: Text(languageName!, style: const TextStyle(color: Colors.white)),
            trailing: currentLocale == languageCode
                ? const Icon(Icons.check, color: Colors.blue)
                : null,
            onTap: () async {
              await languageProvider.setLanguage(languageCode);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Language changed to $languageName'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

// Create placeholder screens for the remaining menu items
class FollowInviteScreen extends StatelessWidget {
  const FollowInviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildPlaceholderScreen('Follow and invite friends');
  }
}

class SupervisionScreen extends StatelessWidget {
  const SupervisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildPlaceholderScreen('Supervision');
  }
}

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildPlaceholderScreen('Payments');
  }
}

class AdsScreen extends StatelessWidget {
  const AdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildPlaceholderScreen('Ads');
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildPlaceholderScreen('Help');
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('About'),
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instagram Clone',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              'A social media app built with Flutter',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              '© 2025 Instagram Clone. All rights reserved.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function for placeholder screens
Widget _buildPlaceholderScreen(String title) {
  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            Text(
              '$title Screen',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming Soon',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    ),
  );
}