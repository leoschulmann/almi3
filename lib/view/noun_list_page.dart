import 'package:flutter/material.dart';

class NounListPage extends StatelessWidget {
  const NounListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Nouns'),
      ),
      body: const Center(child: Text('Nouns Page')),
    );
  }
}
