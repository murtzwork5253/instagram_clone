import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient client() {
    final supabase = Supabase.instance.client;

    return supabase;
  }

  static User? currentUser() {
    return client().auth.currentUser;
  }
}
