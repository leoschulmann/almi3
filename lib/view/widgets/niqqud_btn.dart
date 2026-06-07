import 'package:flutter/material.dart';

class NiqqudBtn extends StatelessWidget {
  const NiqqudBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Text('אָ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      onPressed: () {
        //todo
      },
      tooltip: 'Toggle niqqud',
    );
  }
}
