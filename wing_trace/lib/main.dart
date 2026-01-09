import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() => runApp(const WingTraceApp());

class WingTraceApp extends StatefulWidget {
  const WingTraceApp({super.key});

  @override
  State<WingTraceApp> createState() => _WingTraceAppState();
  
  // This static method allows child widgets to find this state and call toggleTheme
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
        scaffoldBackgroundColor: const Color(0xFFFDFBE7), // Your cream color
        appBarTheme: const AppBarTheme(backgroundColor: Colors.green, foregroundColor: Colors.white),
      ),
      // Dark Theme Definition
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121212), // Standard dark grey/black
        appBarTheme: AppBarTheme(backgroundColor: Colors.green[900]),
      ),
      themeMode: _themeMode,
      home: const SplashScreen(),
    );
  }
}