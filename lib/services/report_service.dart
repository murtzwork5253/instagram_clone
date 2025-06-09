import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> report({
    required String targetType, // 'user', 'post', 'comment', 'reel'
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not logged in');

    await _supabase.from('reports').insert({
      'reporter_id': currentUserId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'details': details,
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
} 