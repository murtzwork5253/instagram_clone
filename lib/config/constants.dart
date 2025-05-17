// Create this file to store your configuration constants
// Path: lib/config/constants.dart

class AppConstants {
  // Google OAuth client ID - move this from the login page to here
  static const String googleClientId =
      '1051202779186-kqac9ms2803rllegshdu2d3n6bjff23h.apps.googleusercontent.com';

  static const String oauthRedirectUrl = 'com.supabase.instagramclone://login-callback/';

  // Add other constants here as needed
  static const int authTimeoutSeconds = 30;
  static const int dbTimeoutSeconds = 10;
}