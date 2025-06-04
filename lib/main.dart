import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:Instagram/screens/splash/splash_screen.dart';
import 'package:Instagram/services/insta_data_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Create a global navigator key that can be used throughout the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Global variable to store a list of available cameras
List<CameraDescription> cameras = [];

Future<void> testEnvLoad() async {
  await dotenv.load(fileName: ".env");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await testEnvLoad();
  await Supabase.initialize(
    url: dotenv.env['BASE_URL'] ?? '',
    anonKey: dotenv.env['API_KEY'] ?? '',
    debug: true,
  );

  // Obtain a list of the available cameras on the device.
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error fetching cameras: $e');
    // Handle error, e.g., show a dialog to the user
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InstaDataProvider()),
        ChangeNotifierProvider(create: (_) => ReelProvider()),
        // other providers...
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add the navigator key here
      theme: ThemeData.dark().copyWith(
        // Customize theme colors to match Instagram
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
