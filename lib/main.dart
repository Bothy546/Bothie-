import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const BothieApp());
}

class BothieApp extends StatelessWidget {
  const BothieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bothie Predictions',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const HomeScreen(),
    );
  }

}
