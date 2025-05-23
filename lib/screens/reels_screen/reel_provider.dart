import 'package:Instagram/screens/reels_screen/reel_modal.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReelProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Reel> reels = [];
  bool isLoading = false;

  Future<void> fetchReels() async {
    isLoading = true;
    notifyListeners();
    final response = await supabase.from('reels').select().order('created_at', ascending: false);
    reels = (response as List).map((e) => Reel.fromMap(e)).toList();
    isLoading = false;
    notifyListeners();
  }
}
