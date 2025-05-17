import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService{

  static SupabaseClient client(){
    final supabase = Supabase.instance.client;

    return supabase;
  }

  static User? currentUser() {
    return client().auth.currentUser;
  }

  static String? userId() {
    return currentUser()?.id;
  }

  static Future<void> signOut() async {
    await client().auth.signOut();
  }

  static Stream<AuthState> authStateChanges() {
    return client().auth.onAuthStateChange;
  }

  static bool isAuthenticated() {
    return currentUser() != null;
  }

}