import 'package:almi3/core/app_colors.dart';
import 'package:flutter/material.dart';

class RootSearchField extends StatelessWidget {
  final TextEditingController controller;

  const RootSearchField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(11),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppColors.inkSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 16, color: AppColors.ink),
              decoration: const InputDecoration(
                hintText: 'Search roots',
                hintStyle: TextStyle(fontSize: 16, color: AppColors.inkSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
