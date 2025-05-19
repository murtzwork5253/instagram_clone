import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;
import 'package:app_links/app_links.dart';
import 'package:Instagram/screens/auth/auth_service.dart';
import 'package:Instagram/screens/auth/profile_completion_screen.dart';
import 'package:Instagram/screens/auth/signup_with_email_screen.dart';
import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:Instagram/config/constants.dart'; // Create this file for storing API keys

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isPasswordFocused = false;
  bool _isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AppConstants.googleClientId,
  );

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(_onPasswordFocusChange);
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Listen to incoming links when app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (!mounted) return;
      debugPrint('Received deep link via app_links stream: $uri');
      _handleIncomingDeepLink(uri);
    });

    // Check if app was started with a deep link
    try {
      // Get the initial uri which launched the app
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        if (!mounted) return;
        debugPrint('Received initial deep link: $initialUri');
        _handleIncomingDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }
  }

  // Centralized deep link handler
  void _handleIncomingDeepLink(Uri uri) {
    debugPrint('Handling deep link: $uri');
    if (uri.scheme == 'com.supabase.instagramclone' &&
        uri.host == 'login-callback') {
      _completeTwitterSignIn();
    }
  }

  Future<void> _completeTwitterSignIn() async {
    _setLoading(true);
    try {
      await Future.delayed(const Duration(seconds: 1));

      final session = AuthService.client().auth.currentSession;
      final user = session?.user;

      if (user != null) {
        await _handleTwitterSession(user);
      } else {
        _showErrorMessage(
            'Twitter Sign-in failed: Could not retrieve user session after redirect.');
        debugPrint('No user session found after Twitter redirect.');
      }
    } catch (e) {
      _showErrorMessage(
          'Twitter Sign-in failed: ${_getReadableErrorMessage(e)}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleTwitterSession(supabase.User user) async {
    try {
      final profileData = await AuthService.client()
          .from('users')
          .select('phone, birthdate, username, email')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profileData == null || profileData['phone'] == null) {
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
        _showSuccessMessage("Twitter Sign-In Successful");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeDashboard()),
        );
      }
    } catch (e) {
      _showErrorMessage(
          'Error loading profile: ${_getReadableErrorMessage(e)}');
    }
  }

  void _onPasswordFocusChange() {
    setState(() {
      _isPasswordFocused = _passwordFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _passwordFocusNode.removeListener(_onPasswordFocusChange);
    _passwordFocusNode.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    _setLoading(true);

    try {
      final response = await AuthService.client().auth.signInWithPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      if (response.user == null) {
        throw Exception('Login failed');
      }

      _showSuccessMessage("Login Successful");

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeDashboard()),
        );
      }
    } catch (e) {
      _showErrorMessage('Login failed: ${_getReadableErrorMessage(e)}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    _setLoading(true);

    try {
      await _googleSignIn.signOut();
      await AuthService.client().auth.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _showMessage('Sign in cancelled');
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('No ID token received from Google');
      }

      final supabase.AuthResponse res = await AuthService.client()
          .auth
          .signInWithIdToken(
            provider: supabase.OAuthProvider.google,
            idToken: googleAuth.idToken!,
            accessToken: googleAuth.accessToken,
          )
          .timeout(const Duration(seconds: 30));

      if (res.user == null) {
        throw Exception('Authentication failed');
      }

      await _handleSuccessfulOAuth(res.user!, googleUser.email, googleUser);
    } on TimeoutException {
      _showErrorMessage('Request timed out. Please try again.');
    } on supabase.AuthException catch (e) {
      _showErrorMessage('Authentication error: ${e.message}');
    } catch (e) {
      _showErrorMessage('Error: ${_getReadableErrorMessage(e)}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleTwitterSignIn() async {
    _setLoading(true);
    try {
      // Sign out first to ensure clean authentication state
      await AuthService.client().auth.signOut();

      final redirectUrl = 'com.supabase.instagramclone://login-callback';

      final authResponse = await AuthService.client().auth.signInWithOAuth(
            supabase.OAuthProvider.twitter,
            redirectTo: redirectUrl,
            scopes: 'email',
          );

      if (!authResponse) {
        throw Exception('Failed to start Twitter authentication flow');
      }

      // We'll show a message about checking the browser
      _showMessage(
          'Please complete authentication in browser. You\'ll be redirected back automatically.');
    } on supabase.AuthException catch (e) {
      _showErrorMessage('Twitter sign-in error: ${e.message}');
    } catch (e) {
      _showErrorMessage(
          'Twitter sign-in failed: ${_getReadableErrorMessage(e)}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleSuccessfulOAuth(supabase.User user, String email,
      [GoogleSignInAccount? googleUser]) async {
    if (!mounted) return;
    try {
      final userRecord = await AuthService.client()
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (userRecord == null && googleUser != null) {
        await _createUserProfile(user, googleUser);
      }

      final profileData = await AuthService.client()
          .from('users')
          .select('phone, birthdate')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profileData == null || profileData['phone'] == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileCompletionScreen(
              user: user,
              email: email,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeDashboard()),
        );
      }
    } catch (e) {
      _showErrorMessage(
          'Error setting up your profile: ${_getReadableErrorMessage(e)}');
    }
  }

  Future<void> _createUserProfile(
    supabase.User user,
    GoogleSignInAccount googleUser,
  ) async {
    final username = await _generateUniqueUsername(googleUser);

    await AuthService.client().from('users').insert({
      'id': user.id,
      'username': username,
      'email': user.email,
      'full_name': googleUser.displayName ?? 'Instagram User',
      'profile_image_url': googleUser.photoUrl,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> _generateUniqueUsername(GoogleSignInAccount googleUser) async {
    String baseUsername = googleUser.displayName?.toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]'),
              '_',
            ) ??
        'user_${googleUser.id.substring(0, min(8, googleUser.id.length))}';

    String finalUsername = baseUsername;
    int suffix = 1;

    while (true) {
      final existing = await AuthService.client()
          .from('users')
          .select()
          .eq('username', finalUsername)
          .maybeSingle();

      if (existing == null) break;

      finalUsername = '$baseUsername$suffix';
      suffix++;
    }

    return finalUsername;
  }

  void _setLoading(bool isLoading) {
    if (mounted) {
      setState(() => _isLoading = isLoading);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showErrorMessage(String message) {
    _showMessage(message);
  }

  void _showSuccessMessage(String message) {
    Fluttertoast.showToast(msg: message);
  }

  String _getReadableErrorMessage(dynamic error) {
    final errorMsg = error.toString();

    if (errorMsg.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    } else if (errorMsg.contains('network')) {
      return 'Network error. Please check your connection';
    }

    return errorMsg;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                Image.asset("assets/images/logo.png", width: 60, height: 60),
                const SizedBox(height: 60),
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
                const SizedBox(height: 20),
                _buildLoginButton(),
                const SizedBox(height: 15),
                _buildForgotPasswordButton(),
                const SizedBox(height: 25),
                _buildSocialLoginOptions(),
                const SizedBox(height: 250),
                _buildCreateAccountButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: "Email",
        prefixIcon: const Icon(Icons.person),
        hintStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      focusNode: _passwordFocusNode,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
      onFieldSubmitted: (_) => _login(),
      decoration: InputDecoration(
        hintText: "Password",
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: _isPasswordFocused
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                splashRadius: 20,
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
              )
            : null,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
            : const Text(
                "Log in",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: () {
        // Navigate to password reset screen
      },
      child: const Text(
        "Forgotten Password?",
        style: TextStyle(
          color: Colors.blue,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSocialLoginOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(OIcons.Bootstrap.google, size: 30),
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          tooltip: 'Sign in with Google',
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: Icon(OIcons.Bootstrap.twitter_x, size: 30, color: Colors.blue),
          onPressed: _isLoading ? null : _handleTwitterSignIn,
          tooltip: 'Sign in with Twitter',
        ),
      ],
    );
  }

  Widget _buildCreateAccountButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SignUpWithEmail(),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.blue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          "Create new account",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
}

int min(int a, int b) {
  return a < b ? a : b;
}
