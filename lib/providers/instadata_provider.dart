// lib/providers/insta_data_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/insta_data_provider.dart'; // Import your ChangeNotifier class

// Define your InstaDataProvider as a ChangeNotifierProvider
final instaDataProvider = ChangeNotifierProvider<InstaDataProvider>((ref) {
  // If your InstaDataProvider needs any services (e.g., SupabaseService),
  // you would instantiate them here using ref.read or ref.watch
  return InstaDataProvider();
});