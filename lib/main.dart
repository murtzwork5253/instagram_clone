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
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// Create a global navigator key that can be used throughout the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Global variable to store a list of available cameras
List<CameraDescription> cameras = [];

Future<void> testEnvLoad() async {
  await dotenv.load(fileName: ".env");
}

// Future<void> _setupPushNotifications() async {
//   try {
//     // Request permissions (iOS and Android 13+)
//     NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//       provisional: false,
//     );
//
//     // Check if permission was granted
//     if (settings.authorizationStatus == AuthorizationStatus.denied) {
//       print('User denied notification permissions');
//       return;
//     }
//
//     // Get and save FCM token with retry logic
//     final user = Supabase.instance.client.auth.currentUser;
//     if (user != null) {
//       String? token = await _getTokenWithRetry();
//       if (token != null) {
//         await _saveFCMTokenToDatabase(user.id, token);
//       }
//     }
//
//     // Listen for token refresh
//     FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
//       final user = Supabase.instance.client.auth.currentUser;
//       if (user != null) {
//         await _saveFCMTokenToDatabase(user.id, newToken);
//       }
//     });
//
//     // Listen for foreground messages
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       _handleForegroundMessage(message);
//     });
//
//     // Listen for notification taps (when app is in background)
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       _handleNotificationTap(message);
//     });
//
//     // Handle notification tap when app is terminated
//     RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
//     if (initialMessage != null) {
//       _handleNotificationTap(initialMessage);
//     }
//
//   } catch (e) {
//     print('Error setting up push notifications: $e');
//     // App should continue to work even if push notifications fail
//   }
// }
//
// Future<String?> _getTokenWithRetry({int maxRetries = 3}) async {
//   for (int i = 0; i < maxRetries; i++) {
//     try {
//       final token = await FirebaseMessaging.instance.getToken();
//       if (token != null) {
//         print('FCM Token obtained: ${token.substring(0, 20)}...');
//         return token;
//       }
//     } catch (e) {
//       print('Attempt ${i + 1} failed to get FCM token: $e');
//       if (i < maxRetries - 1) {
//         await Future.delayed(Duration(seconds: 2 * (i + 1))); // Exponential backoff
//       }
//     }
//   }
//   print('Failed to get FCM token after $maxRetries attempts');
//   return null;
// }
//
// Future<void> _saveFCMTokenToDatabase(String userId, String token) async {
//   try {
//     await Supabase.instance.client
//         .from('users')
//         .update({
//       'fcm_token': token,
//       'fcm_token_updated_at': DateTime.now().toIso8601String(),
//     })
//         .eq('id', userId);
//     print('FCM token saved to database');
//   } catch (e) {
//     print('Error saving FCM token to database: $e');
//   }
// }
//
// void _handleForegroundMessage(RemoteMessage message) {
//   final notification = message.notification;
//   if (notification != null) {
//     final context = navigatorKey.currentContext;
//     if (context != null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 notification.title ?? 'Notification',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               if (notification.body != null)
//                 Text(notification.body!),
//             ],
//           ),
//           duration: const Duration(seconds: 3),
//           action: SnackBarAction(
//             label: 'View',
//             onPressed: () => _handleNotificationTap(message),
//           ),
//         ),
//       );
//     }
//   }
// }
//
// void _handleNotificationTap(RemoteMessage message) {
//   final data = message.data;
//   final context = navigatorKey.currentContext;
//
//   if (context != null && data.isNotEmpty) {
//     // Add a small delay to ensure the app is fully loaded
//     Future.delayed(Duration(milliseconds: 500), () {
//       try {
//         // Navigate based on notification payload
//         if (data['type'] == 'post' && data['postId'] != null) {
//           // Navigate to specific post
//           Navigator.pushNamed(
//             context,
//             '/post/${data['postId']}',
//             arguments: {'postId': data['postId']},
//           );
//         } else if (data['type'] == 'profile' && data['userId'] != null) {
//           // Navigate to user profile
//           Navigator.pushNamed(
//             context,
//             '/profile/${data['userId']}',
//             arguments: {'userId': data['userId']},
//           );
//         } else if (data['type'] == 'chat' && data['chatId'] != null) {
//           // Navigate to chat
//           Navigator.pushNamed(
//             context,
//             '/chat/${data['chatId']}',
//             arguments: {'chatId': data['chatId']},
//           );
//         } else {
//           // Default navigation - maybe to notifications page
//           Navigator.pushNamed(context, '/notifications');
//         }
//       } catch (e) {
//         print('Error handling notification tap: $e');
//       }
//     });
//   }
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await testEnvLoad();
  await _requestAllPermissions();
  await Firebase.initializeApp();
  // OneSignal.initialize("ba1e8b57-044c-42dd-8998-f3556dc20030");
  // String? token = await FirebaseMessaging.instance.getToken();
  // print("FCM Token: $token");
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

  // Initialize push notifications
  await PushNotificationService.initialize(navigatorKey);

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

Future<void> _requestAllPermissions() async {
  // List of all permissions you might need
  final permissions = [
    Permission.camera,
    Permission.microphone,
    Permission.storage, // Android < 13
    Permission.photos,  // iOS
    Permission.notification,
    Permission.videos,  // iOS 17+
    Permission.audio,
    Permission.sensors,
    Permission.location,
    Permission.bluetooth,
    Permission.accessMediaLocation,
    Permission.manageExternalStorage, // Android 11+
    Permission.activityRecognition,
    Permission.sms,
    Permission.contacts,
    Permission.calendar,
    Permission.phone,
  ];
  Map<Permission, PermissionStatus> statuses = await permissions.request();
  // If any permission is denied, show a dialog
  if (statuses.values.any((status) => status.isDenied || status.isPermanentlyDenied)) {
    // Optionally, show a dialog or guide user to settings
    // For now, print to console
    print('Some permissions were denied. Please enable them in app settings.');
  }
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
            // Locale('fr'), // French
            // Locale('de'), // German
            // Locale('it'), // Italian
            // Locale('pt'), // Portuguese
            // Locale('ja'), // Japanese
            // Locale('ko'), // Korean
            // Locale('zh'), // Chinese
            // Locale('hi'), // Hindi
          ],
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
