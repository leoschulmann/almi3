import 'dart:ui';
import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/view/font_picker_page.dart';
import 'package:almi3/view/sync_page.dart';
import 'package:almi3/viewmodel/settings_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black38,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.4],
        expand: false,
        builder: (ctx, scrollController) => _SettingsSheet(scrollController: scrollController),
      );
    },
  );
}

// ---------------------------------------------------------------------------

class _SettingsSheet extends ConsumerWidget {
  final ScrollController scrollController;
  const _SettingsSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: Stack(
          children: [
            // Scrollable content
            CustomScrollView(
              controller: scrollController,
              slivers: [
                // Inline nav bar (pinned)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SettingsNavBarDelegate(
                    onDone: () => Navigator.of(context).pop(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      _buildContent(context, settings, notifier),
                    ),
                  ),
                ),
              ],
            ),
            // Drag handle — sits on top, doesn't scroll
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(
    BuildContext context,
    AppSettings s,
    SettingsNotifier n,
  ) {
    return [
      // ── General ──────────────────────────────────────────────────────────
      _SectionHeader('General'),
      _SettingsGroup(children: [
        _DisclosureRow(
          label: 'Language',
          value: s.language == AppLanguage.ru ? 'Russian' : 'English',
          onTap: () => _showLanguagePicker(context, s, n),
        ),
      ]),

      // ── Appearance ───────────────────────────────────────────────────────
      _SectionHeader('Appearance'),
      _SettingsGroup(children: [
        // Theme segmented control — TODO: apply theme live
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: AdaptiveSegmentedControl<AppTheme>(
            segments: const [
              (AppTheme.light, 'Light'),
              (AppTheme.dark, 'Dark'),
              (AppTheme.auto, 'Auto'),
            ],
            selected: s.theme,
            onChanged: n.setTheme,
          ),
        ),
        _DisclosureRow(
          label: 'App display font',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'אבג',
                style: GoogleFonts.getFont(s.appFont, fontSize: 20, color: AppColors.ink),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(width: 8),
              Text(s.appFont.split(' ').take(2).join(' '),
                  style: const TextStyle(fontSize: 16, color: AppColors.inkSecondary)),
            ],
          ),
          onTap: () => _pushFontPicker(
            context,
            title: 'App font',
            fonts: kAppFonts,
            selected: [s.appFont],
            multiSelect: false,
            onChanged: (fonts) => n.setAppFont(fonts.first),
          ),
        ),
        _ToggleRow(
          label: 'Show transliteration',
          subLabel: 'Latin spelling beneath Hebrew words',
          value: s.showTransliteration,
          onChanged: n.setShowTransliteration,
        ),
        _ToggleRow(
          label: 'Disable root parallax',
          subLabel: 'Stops the watermark drift on cards',
          value: s.disableRootParallax,
          onChanged: n.setDisableRootParallax,
        ),
      ]),

      // ── Practice ─────────────────────────────────────────────────────────
      _SectionHeader('Practice'),
      _SettingsGroup(children: [
        _DisclosureRow(
          label: 'Review intensity',
          value: _intensityLabel(s.reviewIntensity),
          onTap: () => _showIntensityPicker(context, s, n),
        ),
        _ToggleRow(
          label: 'Daily reminder',
          subLabel: 'A nudge to keep words fresh',
          value: s.dailyReminder,
          onChanged: n.setDailyReminder,
        ),
        _DisclosureRow(
          label: 'Reminder time',
          value: s.reminderTime.format(context),
          onTap: () => _showTimePicker(context, s, n),
        ),
        _DisclosureRow(
          label: 'Quiz font',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'אבג',
                style: GoogleFonts.getFont(s.quizFonts.first, fontSize: 20, color: AppColors.ink),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(width: 8),
              Text(
                s.quizFonts.length == 1
                    ? s.quizFonts.first.split(' ').take(2).join(' ')
                    : '${s.quizFonts.length} fonts',
                style: const TextStyle(fontSize: 16, color: AppColors.inkSecondary),
              ),
            ],
          ),
          onTap: () => _pushFontPicker(
            context,
            title: 'Quiz font',
            fonts: kQuizFonts,
            selected: s.quizFonts,
            multiSelect: true,
            onChanged: n.setQuizFonts,
          ),
        ),
      ]),

      // ── Audio ─────────────────────────────────────────────────────────────
      _SectionHeader('Audio'),
      _SettingsGroup(children: [
        _ToggleRow(
          label: 'Autoplay audio',
          subLabel: 'Play a word when it opens',
          value: s.autoplayAudio,
          leadingIcon: _LeadIcon(icon: Icons.volume_up_rounded, color: const Color(0xFFFF2D55)),
          onChanged: n.setAutoplayAudio,
        ),
        _ToggleRow(
          label: 'Download over Wi-Fi only',
          value: s.wifiOnlyDownloads,
          leadingIcon: _LeadIcon(icon: Icons.wifi_rounded, color: const Color(0xFF5B9BFF)),
          onChanged: n.setWifiOnlyDownloads,
        ),
      ]),

      // ── Storage & sync ────────────────────────────────────────────────────
      _SectionHeader('Storage & sync'),
      _SettingsGroup(children: [
        _DisclosureRow(
          label: 'Sync now',
          subLabel: _syncSubLabel(s.lastSyncedAt),
          leadingIcon: _LeadIcon(icon: Icons.sync_rounded, color: const Color(0xFF34C759)),
          onTap: () => _openSync(context),
        ),
        _ValueRow(
          label: 'Dictionary',
          value: '48.2 MB',
          leadingIcon: _LeadIcon(icon: Icons.storage_rounded, color: const Color(0xFF5B9BFF)),
        ),
        _ValueRow(
          label: 'Audio cache',
          value: '112 MB',
          leadingIcon: _LeadIcon(icon: Icons.access_time_rounded, color: const Color(0xFFFF9F0A)),
        ),
        _ActionRow(
          label: 'Clear audio cache',
          destructive: true,
          leadingIcon: _LeadIcon(icon: Icons.delete_outline_rounded, color: const Color(0xFFFF3B30)),
          onTap: () {/* TODO: clear audio cache */},
        ),
      ]),

      // ── Reset (standalone) ────────────────────────────────────────────────
      const SizedBox(height: 18),
      _SettingsGroup(children: [
        _ActionRow(
          label: 'Reset all progress',
          destructive: true,
          leadingIcon: _LeadIcon(icon: Icons.restart_alt_rounded, color: const Color(0xFFFF9500)),
          onTap: () => _confirmReset(context),
        ),
      ]),

      // ── About ─────────────────────────────────────────────────────────────
      _SectionHeader('About'),
      _SettingsGroup(children: [
        _DisclosureRow(
          label: 'Rate ALMI',
          leadingIcon: _LeadIcon(icon: Icons.star_rounded, color: const Color(0xFFFFCC00)),
          onTap: () {/* TODO */},
        ),
        _DisclosureRow(
          label: 'Send feedback',
          leadingIcon: _LeadIcon(icon: Icons.chat_bubble_rounded, color: const Color(0xFF34C759)),
          onTap: () {/* TODO */},
        ),
        _DisclosureRow(
          label: 'Privacy policy',
          leadingIcon: _LeadIcon(icon: Icons.lock_rounded, color: const Color(0xFF8E8E93)),
          onTap: () {/* TODO */},
        ),
        _DisclosureRow(
          label: 'Font licenses',
          leadingIcon: _LeadIcon(icon: Icons.description_rounded, color: const Color(0xFF5B9BFF)),
          onTap: () {/* TODO */},
        ),
      ]),

      const Padding(
        padding: EdgeInsets.only(top: 22, bottom: 6),
        child: Text(
          'ALMI · version 1.0',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFFAEAEB2)),
        ),
      ),
    ];
  }

  String _intensityLabel(ReviewIntensity v) {
    switch (v) {
      case ReviewIntensity.relaxed:
        return 'Relaxed';
      case ReviewIntensity.normal:
        return 'Normal';
      case ReviewIntensity.intense:
        return 'Intense';
    }
  }

  String _syncSubLabel(DateTime? lastSynced) {
    if (lastSynced == null) return 'Never synced';
    final now = DateTime.now();
    final diff = now.difference(lastSynced);
    if (diff.inMinutes < 1) return 'Last synced just now';
    if (diff.inHours < 1) return 'Last synced ${diff.inMinutes}m ago';
    if (diff.inDays == 0) return 'Last synced today, ${_formatTime(lastSynced)}';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'Last synced ${months[lastSynced.month - 1]} ${lastSynced.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _pushFontPicker(
    BuildContext context, {
    required String title,
    required List<String> fonts,
    required List<String> selected,
    required bool multiSelect,
    required void Function(List<String>) onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        expand: false,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: FontPickerPage(
            title: title,
            fontNames: fonts,
            selected: selected,
            multiSelect: multiSelect,
            onChanged: onChanged,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context, AppSettings s, SettingsNotifier n) async {
    final picked = await showAdaptiveOptionPicker<AppLanguage>(
      context,
      title: 'Language',
      current: s.language,
      options: const [
        (AppLanguage.en, 'English'),
        (AppLanguage.ru, 'Russian'),
      ],
    );
    if (picked != null) n.setLanguage(picked);
  }

  Future<void> _showIntensityPicker(BuildContext context, AppSettings s, SettingsNotifier n) async {
    final picked = await showAdaptiveOptionPicker<ReviewIntensity>(
      context,
      title: 'Review intensity',
      current: s.reviewIntensity,
      options: ReviewIntensity.values.map((v) => (v, _intensityLabel(v))).toList(),
    );
    if (picked != null) n.setReviewIntensity(picked);
  }

  Future<void> _showTimePicker(BuildContext context, AppSettings s, SettingsNotifier n) async {
    final picked = await showAdaptiveTimePicker(context, s.reminderTime);
    if (picked != null) n.setReminderTime(picked);
  }

  void _openSync(BuildContext context) {
    Navigator.of(context).push(
      adaptivePageRoute(builder: (_) => const SyncPage()),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showAdaptiveConfirmDialog(
      context,
      title: 'Reset all progress?',
      message: 'This will delete all your learning history and word health data. This cannot be undone.',
      destructiveLabel: 'Reset',
    );
    if (confirmed) {
      // TODO: wipe word_progress table
    }
  }
}

// ---------------------------------------------------------------------------
// Pinned nav bar delegate

class _SettingsNavBarDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onDone;
  const _SettingsNavBarDelegate({required this.onDone});

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 60,
          decoration: const BoxDecoration(
            color: AppColors.navBarBackground,
            border: Border(bottom: BorderSide(color: Color(0x21000000), width: 0.5)),
          ),
          alignment: Alignment.center,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 80),
                  child: Text(
                    'Settings',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: onDone,
                  child: const Center(
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tekhelet,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SettingsNavBarDelegate old) => false;
}

// ---------------------------------------------------------------------------
// Layout primitives

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 7),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.inkSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _RowBase extends StatelessWidget {
  final Widget? leadingIcon;
  final Widget label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _RowBase({
    required this.label,
    this.leadingIcon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x14000000), width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            if (leadingIcon != null) ...[leadingIcon!, const SizedBox(width: 12)],
            label,
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  final String label;
  final String? subLabel;
  final String? value;
  final Widget? trailing;
  final Widget? leadingIcon;
  final VoidCallback onTap;

  const _DisclosureRow({
    required this.label,
    this.subLabel,
    this.value,
    this.trailing,
    this.leadingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _RowBase(
      leadingIcon: leadingIcon,
      onTap: onTap,
      label: Expanded(
        child: subLabel != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
                  Text(subLabel!, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSecondary)),
                ],
              )
            : Text(label, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing!
          else if (value != null)
            Text(value!, style: const TextStyle(fontSize: 16, color: AppColors.inkSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFAEAEB2)),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String? subLabel;
  final Widget? leadingIcon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    this.subLabel,
    this.leadingIcon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _RowBase(
      leadingIcon: leadingIcon,
      onTap: () => onChanged(!value),
      label: Expanded(
        child: subLabel != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
                  Text(subLabel!, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSecondary)),
                ],
              )
            : Text(label, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.tekhelet,
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? leadingIcon;

  const _ValueRow({
    required this.label,
    required this.value,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return _RowBase(
      leadingIcon: leadingIcon,
      label: Expanded(
        child: Text(label, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
      ),
      trailing: Text(value, style: const TextStyle(fontSize: 16, color: AppColors.inkSecondary)),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final bool destructive;
  final Widget? leadingIcon;
  final VoidCallback onTap;

  const _ActionRow({
    required this.label,
    this.destructive = false,
    this.leadingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _RowBase(
      leadingIcon: leadingIcon,
      onTap: onTap,
      label: Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: destructive ? const Color(0xFFFF3B30) : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom switch (tekhelet on-track)

// ---------------------------------------------------------------------------
// Leading icon

class _LeadIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _LeadIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}


