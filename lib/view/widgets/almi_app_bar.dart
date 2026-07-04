import 'dart:ui';
import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/view/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Shared frosted-glass app bar used across all ALMI screens.
// Matches the pinned bar style of RootListPage.
class AlmiAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final bool showActions; // niqqud + settings
  final List<Widget> extraActions;

  const AlmiAppBar({
    super.key,
    this.title,
    this.showActions = true,
    this.extraActions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AppBar(
            backgroundColor: AppColors.navBarBackground,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              child: title ?? const SizedBox.shrink(),
            ),
            iconTheme: const IconThemeData(color: AppColors.tekhelet),
            actions: [
              ...extraActions,
              if (showActions) ...[
                AdaptiveIconButton(
                  tooltip: 'Toggle niqqud',
                  onPressed: () {/* TODO: toggle niqqud */},
                  icon: const Text(
                    'אָ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tekhelet,
                    ),
                  ),
                ),
                AdaptiveIconButton(
                  tooltip: 'Settings',
                  onPressed: () => showSettingsSheet(context),
                  icon: const Icon(
                    Icons.settings_outlined,
                    size: 22,
                    color: AppColors.tekhelet,
                  ),
                ),
              ],
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(height: 0.5, color: AppColors.hairline),
            ),
          ),
        ),
      ),
    );
  }
}
