import 'package:flutter/material.dart';

class RidePreferencesScreen extends StatelessWidget {
  const RidePreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Rides")),
      body: const Center(child: Text("My Rides Screen")),
    );
  }
}
