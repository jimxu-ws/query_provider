import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'examples/background_foreground_example.dart';
import 'examples/background_refetch_example.dart';
import 'examples/window_focus_example.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    // Use ProviderScope to ensure all providers share the same container
    // This is critical for QueryClient to properly invalidate providers
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp2 extends StatelessWidget {
  const MyApp2({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BackgroundForegroundExample',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BackgroundForegroundExample(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Query Provider Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
