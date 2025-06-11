import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:Instagram/screens/splash/splash_screen.dart';
import 'package:Instagram/services/insta_data_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'providers/language_provider.dart';

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
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

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
