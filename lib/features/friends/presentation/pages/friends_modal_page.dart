import 'package:flutter/material.dart';

class FriendsModalPage extends StatelessWidget {
  const FriendsModalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amis'),
      ),
      body: Center(
        child: Text(
          'Amis',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
