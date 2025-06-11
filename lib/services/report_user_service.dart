import 'package:supabase_flutter/supabase_flutter.dart';

class ReportUserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not logged in');

    await _supabase.from('user_reports').insert({
      'reporter_id': currentUserId,
      'reported_id': reportedUserId,
      'reason': reason,
      'details': details,
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
} 