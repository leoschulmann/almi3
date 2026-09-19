import 'package:almi3/core/app_colors.dart';
import 'package:flutter/material.dart';

/// Placeholder navigation target for "Тренировка" until free practice
/// (story 1.8) replaces it. No FSRS/practice logic here.
class PracticeStubPage extends StatelessWidget {
  const PracticeStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        elevation: 0,
        title: const Text('Тренировка'),
      ),
      body: const Center(
        child: Text(
          'Здесь будет свободная тренировка',
          style: TextStyle(fontSize: 15, color: AppColors.inkSecondary),
        ),
      ),
    );
  }
}
