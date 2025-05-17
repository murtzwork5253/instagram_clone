import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:Instagram/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://kprizlkexocjxvygfbyn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtwcml6bGtleG9janh2eWdmYnluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcxOTk4NDksImV4cCI6MjA2Mjc3NTg0OX0.GF5O_3TG8FPuH-GJKrLrYMroVepx3vwvgHvquSuFl6I',
    debug: true,
  );
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
