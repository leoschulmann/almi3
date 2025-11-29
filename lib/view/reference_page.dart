import 'package:flutter/material.dart';

class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Reference'),
      ),
      body: const Center(
        child: Text('Reference Page'),
      ),
    );
  }
}
