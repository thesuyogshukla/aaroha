import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home/home_screen.dart';

void main() => runApp(const ProviderScope(child: AarohaApp()));

class AarohaApp extends StatelessWidget {
  const AarohaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF8D5A2B); // bamboo
    return MaterialApp(
      title: 'Aaroha',
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
