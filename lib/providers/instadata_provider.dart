// lib/providers/insta_data_provider.dart
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../services/insta_data_provider.dart'; // Import your ChangeNotifier class

// Define your InstaDataProvider as a ChangeNotifierProvider
SingleChildWidget createInstaDataProvider() {
  return ChangeNotifierProvider<InstaDataProvider>(
    create: (_) => InstaDataProvider(),
  );
}