import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';

/// Main DevTools extension application for JankKiller.
class JankKillerDevToolsApp extends StatelessWidget {
  const JankKillerDevToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
