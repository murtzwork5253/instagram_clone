// profile_settings_menu.dart
import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../../providers/language_provider.dart';
import '../../services/account_manager.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';
import '../auth/login_page.dart';
import '../auth/password_change_screen.dart';
import '../auth/service/auth_service.dart';
import '../profilescreen/blocked_users_screen.dart';
import 'package:Instagram/screens/notificationscreen/service/notification_service.dart';
import 'package:Instagram/screens/notificationscreen/model/notification_model.dart';

import '../saved_posts/saved_post_screen.dart';

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

  // Enhanced logout function for current account only
  Future<void> _logout() async {
    try {
      // Show confirmation dialog
      bool shouldLogout = await _showLogoutConfirmation();
      if (!shouldLogout) return;

      // Get current account ID before signing out
      final currentAccountId = await AccountManager.instance.getCurrentAccountId();

      // 1. Sign out from Google
      await _googleSignIn.signOut();

      // 2. Sign out from Supabase
      await AuthService.client().auth.signOut();

      // 3. Remove current account from stored accounts
      if (currentAccountId != null) {
        await AccountManager.instance.removeAccount(currentAccountId);
      }

      // 4. Reset provider data
      Provider.of<InstaDataProvider>(context, listen: false).reset();

      // 5. Check if there are other stored accounts
      final remainingAccounts = await AccountManager.instance.getStoredAccounts();

      if (remainingAccounts.isNotEmpty) {
        // Switch to the first available account
        final nextAccount = remainingAccounts.first;
        final switchSuccess = await AccountManager.instance.switchToAccount(nextAccount.userId, context);

        if (switchSuccess) {
          // Successfully switched to another account, go back to main app
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomeDashboard()), // Replace with your main screen
                  (route) => false,
            );
          }
          return;
        }
      }

      // No other accounts available or switch failed, navigate to login screen
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

// New method for logging out all accounts
  Future<void> _logoutAllAccounts() async {
    try {
      // Show confirmation dialog
      bool shouldLogout = await _showLogoutAllConfirmation();
      if (!shouldLogout) return;

      // 1. Sign out from Google
      await _googleSignIn.signOut();

      // 2. Sign out from all accounts using AccountManager
      await AccountManager.instance.signOutAll();

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

// Updated confirmation dialog for single account logout
  Future<bool> _showLogoutConfirmation() async {
    final loc = AppLocalizations.of(context)!;
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(loc.logout, style: const TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to logout from this account? This will remove the account from your saved accounts.',
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

// New confirmation dialog for all accounts logout
  Future<bool> _showLogoutAllConfirmation() async {
    final loc = AppLocalizations.of(context)!;
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Logout All Accounts', style: const TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to logout from all accounts? This will remove all saved accounts and you will need to sign in again.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(loc.cancel, style: const TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Logout All', style: const TextStyle(color: Colors.red)),
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

            // // Logout Section
            // _buildMenuItem(
            //   ,
            //   loc.logout,
            //   _logout,
            //   false,
            // ),

            ListTile(
              title: Text(
                "Logout",
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              onTap: _logout,
            ),
            ListTile(
              title: Text(
                "Logout All Accounts",
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              onTap: _logoutAllAccounts,
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
  UserData? _currentUser;
  late final profileImageUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentUserData();
    });
  }

  void _fetchCurrentUserData() {
    final provider = Provider.of<InstaDataProvider>(context, listen: false);
    final user = provider.currentUser;
    if (user != null) {
      final bool isFullUrl =
          Uri.tryParse(user.profileImageUrl!)?.hasAbsolutePath == true &&
              (user.profileImageUrl!.startsWith('http://') ||
                  user.profileImageUrl!.startsWith('https://'));

      profileImageUrl = isFullUrl
          ? user.profileImageUrl!
          : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${user.profileImageUrl}';
    }
    if (user != null) {
      setState(() {
        _currentUser = user;
        _usernameController.text = user.username;
        _emailController.text = user.email!;
        _bioController.text = user.bio ?? '';
      });
    }
  }

  Future<void> _showImagePicker(String? userId) async {
    print('_showImagePicker called with userId: $userId');
    if (userId == null) {
      _showErrorSnackBar('Error: User not logged in');
      return;
    }

    final BuildContext context = this.context;

    try {
      List<Permission> permissionsToRequest = [
        Permission.camera,
        Permission.storage,
        Permission.photos,
      ];

      final statuses = await permissionsToRequest.request();
      final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final storageAccess =
          (statuses[Permission.storage]?.isGranted ?? false) ||
              (statuses[Permission.photos]?.isGranted ?? false);

      if (!cameraGranted || !storageAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
              Text('Please grant required permissions to update picture'),
            ),
          );
        }
        return;
      }
    } catch (e) {
      _showErrorSnackBar('Please grant camera and storage access in settings');
      return;
    }

    try {
      final picker = ImagePicker();
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.grey[900],
        builder: (BuildContext ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Update Profile Picture',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.blue),
                  title: const Text("Photo Gallery"),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text("Camera"),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      );

      if (source != null && mounted) {
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 75,
          maxWidth: 800,
        );

        if (image != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );

          try {
            final bytes = await image.readAsBytes();
            final fileName =
                'public/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

            await Supabase.instance.client.storage.from('avatars').uploadBinary(
                fileName, bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'));

            Navigator.of(context).pop(); // close loading

            await Supabase.instance.client
                .from('users')
                .update({'profile_image_url': fileName}).eq('id', userId);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile image updated')),
            );

            // Trigger a rebuild to reflect the new avatar URL, which will cause _loadProfileData to re-run
            // or you can manually update the avatarUrl and call setState.
            // For now, setState will re-run build. To refresh _loadProfileData, you'd need to call it again.
            // Let's call _loadProfileData again to ensure avatarUrl is correctly updated from Supabase.
            setState(() {});
          } catch (e) {
            if (mounted) Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading image: $e')),
            );
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } else if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
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
                    radius: 49,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                    child: profileImageUrl == null
                        ? const Icon(Icons.person, color: Colors.white, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 5),
                  TextButton(
                    onPressed: () {
                      // // Handle profile picture change
                      _showImagePicker(_currentUser?.id);
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
      onTap: () => _handleAccountOptionTap(title),
    );
  }

  void _handleAccountOptionTap(String title) {
    switch (title) {
      case 'Personal Information':
        _showErrorSnackBar('Coming soon: Personal Information');
        break;
      case 'Professional Dashboard':
        _showErrorSnackBar('Coming soon: Dashboard with stats');
        break;
      case 'Account Status':
        _showErrorSnackBar('Your account is currently active');
        break;
      case 'Download Your Data':
        _downloadUserData();
        break;
      case 'Delete Account':
        _confirmDeleteAccount();
        break;
    }
  }

  void _downloadUserData() async {
    final userId = _currentUser?.id;
    if (userId == null) return;

    final userResponse = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    if (userResponse != null) {
      final data = userResponse;
      final jsonData = data.toString(); // You can format this better

      // You can also save it locally using path_provider + file io
      _showErrorSnackBar('User data prepared:\n$jsonData');
    } else {
      _showErrorSnackBar('Unable to fetch user data');
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure? All your data will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    final userId = _currentUser?.id;
    if (userId == null) {
      _showErrorSnackBar('Error: No user ID found');
      return;
    }

    try {
      final client = Supabase.instance.client;

      // Optional: Delete related content like posts, comments, reels etc.
      await client.from('story_views').delete().eq('viewer_id', userId);
      await client.from('story_likes').delete().eq('user_id', userId);
      await client.from('stories').delete().eq('user_id', userId);
      await client.from('saved_posts').delete().eq('user_id', userId);
      await client.from('reels').delete().eq('user_id', userId);
      await client.from('reel_likes').delete().eq('user_id', userId);
      await client.from('posts').delete().eq('user_id', userId);
      await client.from('post_likes').delete().eq('user_id', userId);
      await client.from('notifications').delete().eq('sender_id', userId);
      await client.from('messages').delete().eq('sender_id', userId);
      await client.from('messages').delete().eq('receiver_id', userId);
      await client.from('notifications').delete().eq('recipient_id', userId);
      await client.from('followers').delete().eq('follower_id', userId);
      await client.from('followers').delete().eq('following_id', userId);
      await client.from('comments').delete().eq('user_id', userId);
      await client.from('comment_likes').delete().eq('user_id', userId);
      await client.from('users').delete().eq('id', userId);

      _showErrorSnackBar('Your account has been deleted');

      // Log out user and redirect
      await client.auth.signOut();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginPage()).settings.name!, (route) => false);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to delete account: $e');
    }
  }



}

// screens/notifications_screen.dart
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final String currentUserId = Supabase.instance.client.auth.currentUser!.id;

  NotificationPreferencesModel? _preferences;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() async {
    final preferences = await _notificationService.getUserNotificationPreferences(currentUserId);
    setState(() {
      _preferences = preferences;
      _isLoading = false;
    });
  }

  void _updatePreference(String type, bool value) async {
    if (_preferences == null) return;

    NotificationPreferencesModel updatedPreferences;

    switch (type) {
      case 'likes':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: value,
          comments: _preferences!.comments,
          follows: _preferences!.follows,
          mentions: _preferences!.mentions,
          stories: _preferences!.stories,
          messages: _preferences!.messages,
        );
        break;
      case 'comments':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: _preferences!.likes,
          comments: value,
          follows: _preferences!.follows,
          mentions: _preferences!.mentions,
          stories: _preferences!.stories,
          messages: _preferences!.messages,
        );
        break;
      case 'follows':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: _preferences!.likes,
          comments: _preferences!.comments,
          follows: value,
          mentions: _preferences!.mentions,
          stories: _preferences!.stories,
          messages: _preferences!.messages,
        );
        break;
      case 'mentions':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: _preferences!.likes,
          comments: _preferences!.comments,
          follows: _preferences!.follows,
          mentions: value,
          stories: _preferences!.stories,
          messages: _preferences!.messages,
        );
        break;
      case 'stories':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: _preferences!.likes,
          comments: _preferences!.comments,
          follows: _preferences!.follows,
          mentions: _preferences!.mentions,
          stories: value,
          messages: _preferences!.messages,
        );
        break;
      case 'messages':
        updatedPreferences = NotificationPreferencesModel(
          userId: _preferences!.userId,
          likes: _preferences!.likes,
          comments: _preferences!.comments,
          follows: _preferences!.follows,
          mentions: _preferences!.mentions,
          stories: _preferences!.stories,
          messages: value,
        );
        break;
      default:
        return;
    }

    await _notificationService.updateNotificationPreferences(updatedPreferences);
    setState(() {
      _preferences = updatedPreferences;
    });
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _preferences == null
              ? const Center(child: Text('Error loading preferences'))
              : ListView(
                  children: [
                    SwitchListTile(
                      title: const Text('Likes', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Get notified when someone likes your content', style: TextStyle(color: Colors.grey)),
                      value: _preferences!.likes,
                      onChanged: (value) => _updatePreference('likes', value),
                      activeColor: Colors.blue,
                      secondary: const Icon(Icons.favorite, color: Colors.white),
                    ),
                    SwitchListTile(
                      title: const Text('Comments', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Get notified when someone comments on your posts', style: TextStyle(color: Colors.grey)),
                      value: _preferences!.comments,
                      onChanged: (value) => _updatePreference('comments', value),
                      activeColor: Colors.blue,
                      secondary: const Icon(Icons.comment, color: Colors.white),
                    ),
                    SwitchListTile(
                      title: const Text('Follows', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Get notified when someone follows you', style: TextStyle(color: Colors.grey)),
                      value: _preferences!.follows,
                      onChanged: (value) => _updatePreference('follows', value),
                      activeColor: Colors.blue,
                      secondary: const Icon(Icons.person_add, color: Colors.white),
                    ),
                    SwitchListTile(
                      title: const Text('Mentions', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Get notified when someone mentions you', style: TextStyle(color: Colors.grey)),
                      value: _preferences!.mentions,
                      onChanged: (value) => _updatePreference('mentions', value),
                      activeColor: Colors.blue,
                      secondary: const Icon(Icons.alternate_email, color: Colors.white),
                    ),
                    SwitchListTile(
                      title: const Text('Stories', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Get notified when someone posts a story', style: TextStyle(color: Colors.grey)),
                      value: _preferences!.stories,
                      onChanged: (value) => _updatePreference('stories', value),
                      activeColor: Colors.blue,
                      secondary: const Icon(Icons.history, color: Colors.white),
                    ),
                    SwitchListTile(
                      title: const Text('Messages', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Get notified when someone sends you a message', style: TextStyle(color: Colors.grey)),
                      value: _preferences!.messages,
                      onChanged: (value) => _updatePreference('messages', value),
                      activeColor: Colors.blue,
                      secondary: const Icon(Icons.message, color: Colors.white),
                    ),
                  ],
                ),
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