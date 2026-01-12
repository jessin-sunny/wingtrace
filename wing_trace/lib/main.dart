import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. IMPORT FIREBASE
import 'firebase_options.dart'; // 2. IMPORT GENERATED OPTIONS
import 'splash_screen.dart';

// 3. CHANGE TO ASYNC MAIN
void main() async {
  // 4. ENSURE BINDING INITIALIZED
  WidgetsFlutterBinding.ensureInitialized();
  
  // 5. INITIALIZE FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const WingTraceApp());
}

class WingTraceApp extends StatefulWidget {
  const WingTraceApp({super.key});

  @override
  State<WingTraceApp> createState() => _WingTraceAppState();
  
  static _WingTraceAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_WingTraceAppState>()!;
}

class _WingTraceAppState extends State<WingTraceApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WingTrace',
      // Light Theme Definition
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFFDFBE7), 
        appBarTheme: const AppBarTheme(backgroundColor: Colors.green, foregroundColor: Colors.white),
      ),
      // Dark Theme Definition
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(backgroundColor: Colors.green[900]),
      ),
      themeMode: _themeMode,
      home: const SplashScreen(),
    );
  }
}