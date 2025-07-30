import 'dart:async'; // Added for StreamSubscription
import 'package:Instagram/screens/calling/call_manager.dart';
import 'package:Instagram/screens/calling/incoming_call_screen.dart';
import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:Instagram/screens/notificationscreen/notification_screen.dart';
import 'package:Instagram/screens/profilescreen/profile_settings_menu.dart';
import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:Instagram/screens/splash/splash_screen.dart';
import 'package:Instagram/services/insta_data_provider.dart';
import 'package:app_links/app_links.dart'; // Added for deep linking
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

// --- No changes in this top section ---
Future<void> testEnvLoad() async {
  await dotenv.load(fileName: ".env");
}
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && token != null) {
      await _saveFCMTokenToDatabase(user.id, token);
    } else {
      print("No authenticated user found or token is null - will save token after login");
    }
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
// --- No changes in this top section ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await testEnvLoad();
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await Supabase.initialize(
      url: dotenv.env['BASE_URL'] ?? '',
      anonKey: dotenv.env['API_KEY'] ?? '',
      debug: true,
    );
    print("Supabase initialized successfully");
    await _setupInitialFCMToken();
    try {
      cameras = await availableCameras();
      print("Cameras initialized: ${cameras.length} cameras found");
    } on CameraException catch (e) {
      print('Error fetching cameras: $e');
    }
    await PushNotificationService.initialize(navigatorKey);
    print("Push notification service initialized");
  } catch (e) {
    print("Error during initialization: $e");
  }
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InstaDataProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ReelProvider()),
      ],
      child: const MyApp(), // Changed to const
    ),
  );
}

// Converted MyApp to a StatefulWidget to handle the deep link listener
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver{
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Initializes the deep link listener.
  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      print('✅ App opened with deep link: $uri');
      // Example link: https://your-site.netlify.app/reel?id=123
      if (uri.path == '/reel' && uri.queryParameters.containsKey('id')) {
        final reelId = uri.queryParameters['id'];
        print('Parsed Reel ID from deep link: $reelId');

        // Navigate to the Home screen and tell it to open the Reels tab
        // with the specific reelId.
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeDashboard(
              initialTabIndex: 3, // 3 is the index for Reels tab
              initialReelId: reelId,
            ),
          ),
              (route) => false,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async { // Make it async
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      final callManager = CallManager();

      // Only proceed if the call UI isn't already visible
      if (!callManager.isCallUIActive) {
        // Check the database for an active call
        final activeCall = await callManager.callService.checkForActiveCall();

        if (activeCall != null && navigatorKey.currentContext != null) {
          // If a call is found, rejoin it
          await callManager.rejoinCall(navigatorKey.currentContext!, activeCall);
        }
      }
    }
  }


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
            Locale('en'),
            Locale('es'),
            Locale('gu'),
          ],
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,

          // onGenerateRoute: (settings){
          //   switch(settings.name) {
          //     // Define a case for your notifications screen
          //     case '/notifications':
          //       final args = settings.arguments as Map<String, dynamic>?;
          //       final userId = args?['userId'];
          //       return MaterialPageRoute(
          //         builder: (context) {
          //           // Return the screen you want to show for notifications
          //           return NotificationScreen();
          //         },
          //       );
          //     default:
          //     // If the route is not found, you can show a default screen
          //     // or an error screen.
          //       return MaterialPageRoute(
          //         builder: (context) => Scaffold(
          //           body: Center(
          //             child: Text('Route not found: ${settings.name}'),
          //           ),
          //         ),
          //       );
          //   };
          // },
        );
      },
    );
  }
}