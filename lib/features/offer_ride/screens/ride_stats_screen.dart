import 'package:flutter/material.dart';

class RideStatsScreen extends StatelessWidget {
  const RideStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Rides")),
      body: const Center(child: Text("My Rides Screen")),
    );
  }
}
