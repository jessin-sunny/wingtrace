import 'package:flutter/material.dart';
import 'main.dart'; // Import main to access WingTraceApp.of

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if the current theme is dark to set the initial switch value
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("App Customization", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
          SwitchListTile(
            secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            title: const Text("Dark Mode"),
            subtitle: Text(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode"),
            value: isDarkMode,
            onChanged: (bool value) {
              // This calls the global toggle function in main.dart
              WingTraceApp.of(context).toggleTheme(value);
            },
            activeColor: Colors.green,
          ),
          const Divider(),
          // ... rest of your hardware settings
        ],
      ),
    );
  }
}