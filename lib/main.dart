import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:Instagram/screens/splash/splash_screen.dart';
import 'package:Instagram/services/insta_data_provider.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'providers/language_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/push_notification_service.dart';

// Create a global navigator key that can be used throughout the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Global variable to store a list of available cameras
List<CameraDescription> cameras = [];

Future<void> testEnvLoad() async {
  await dotenv.load(fileName: ".env");
}

// Background message handler - must be top level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  // Additional background processing can be added here
}

Future<void> _saveFCMTokenToDatabase(String userId, String token) async {
  try {
    await Supabase.instance.client
        .from('users')
        .update({
      'fcm_token': token,
      'fcm_token_updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', userId);
    print('FCM token saved to database for user: $userId');
  } catch (e) {
    print('Error saving FCM token to database: $e');
  }
}

Future<void> _setupInitialFCMToken() async {
  try {
    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $token");

    // Check if user is authenticated before saving token
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && token != null) {
      await _saveFCMTokenToDatabase(user.id, token);
    } else {
      print("No authenticated user found or token is null - will save token after login");
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print("FCM Token refreshed: $newToken");
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await _saveFCMTokenToDatabase(currentUser.id, newToken);
      }
    });

  } catch (e) {
    print("Error getting or saving FCM token: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables first
    await testEnvLoad();

    // Initialize Firebase FIRST
    await Firebase.initializeApp();
    print("Firebase initialized successfully");

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['BASE_URL'] ?? '',
      anonKey: dotenv.env['API_KEY'] ?? '',
      debug: true,
    );
    print("Supabase initialized successfully");

    

    // Setup FCM token handling
    await _setupInitialFCMToken();

    // Initialize cameras
    try {
      cameras = await availableCameras();
      print("Cameras initialized: ${cameras.length} cameras found");
    } on CameraException catch (e) {
      print('Error fetching cameras: $e');
    }

    // Initialize push notifications service
    await PushNotificationService.initialize(navigatorKey);
    print("Push notification service initialized");

  } catch (e) {
    print("Error during initialization: $e");
  }

  // Reduce image cache to prevent buffer overflow
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InstaDataProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ReelProvider()),
      ],
      child: MyApp(),
    ),
  );
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData.dark().copyWith(
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
          locale: languageProvider.currentLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('es'), // Spanish
            Locale('gu'), // Gujarati
          ],
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}