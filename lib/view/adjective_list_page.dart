import 'package:flutter/material.dart';

class AdjectiveListPage extends StatelessWidget {
  const AdjectiveListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Adjectives'),
      ),
      body: const Center(child: Text('Adjectives Page')),
    );
  }
}
