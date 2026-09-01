import 'package:flutter/material.dart';

void main() {
  runApp(const PlanetsApp());
}

class PlanetsApp extends StatelessWidget {
  const PlanetsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'PLANETS',
      debugShowCheckedModeBanner: false,
      home: PlanetsBootstrapScreen(),
    );
  }
}

class PlanetsBootstrapScreen extends StatelessWidget {
  const PlanetsBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PLANETS', style: TextStyle(fontSize: 32)),
              SizedBox(height: 12),
              Text('Mobile application bootstrap'),
            ],
          ),
        ),
      ),
    );
  }
}
