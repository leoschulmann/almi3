import 'package:almi3/core/app_colors.dart';
import 'package:flutter/material.dart';

/// Placeholder navigation target for "Учиться" until the unified session
/// (story 1.4) replaces it. No FSRS/session logic here.
class SessionStubPage extends StatelessWidget {
  const SessionStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        elevation: 0,
        title: const Text('Сессия'),
      ),
      body: const Center(
        child: Text(
          'Здесь будет учебная сессия',
          style: TextStyle(fontSize: 15, color: AppColors.inkSecondary),
        ),
      ),
    );
  }
}
