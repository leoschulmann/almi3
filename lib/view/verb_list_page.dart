import 'package:flutter/material.dart';

class VerbListPage extends StatelessWidget {
  const VerbListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Verbs'),
      ),
      body: const Center(child: Text('Verbs Page')),
    );
  }
}
