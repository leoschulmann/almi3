import 'dart:ui';
import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/core/platform_ui.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:almi3/view/font_picker_page.dart';
import 'package:almi3/view/ignored_words_page.dart';
import 'package:almi3/view/known_words_page.dart';
import 'package:almi3/view/sync_page.dart';
import 'package:almi3/viewmodel/home_notifier.dart' show ignoredWordsCountProvider, knownWordsCountProvider;
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
                      _buildContent(context, ref, settings, notifier),
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
    WidgetRef ref,
    AppSettings s,
    SettingsNotifier n,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final ignoredCountAsync = ref.watch(ignoredWordsCountProvider);
    final ignoredLabel = ignoredCountAsync.when(
      data: (count) => l10n.removedCount(count),
      loading: () => l10n.removedCountLoading,
      error: (_, _) => l10n.removedCountError,
    );
    final knownCountAsync = ref.watch(knownWordsCountProvider);
    final knownLabel = knownCountAsync.when(
      data: (count) => l10n.knownCount(count),
      loading: () => l10n.knownCountLoading,
      error: (_, _) => l10n.knownCountError,
    );

    return [
      // ── General ──────────────────────────────────────────────────────────
      _SectionHeader(l10n.generalSection),
      _SettingsGroup(children: [
        _DisclosureRow(
          label: l10n.languageLabel,
          value: s.language.label(l10n),
          onTap: () => _showLanguagePicker(context, s, n),
        ),
      ]),

      // ── Appearance ───────────────────────────────────────────────────────
      _SectionHeader(l10n.appearanceSection),
      _SettingsGroup(children: [
        // Theme segmented control — TODO: apply theme live
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: AdaptiveSegmentedControl<AppTheme>(
            segments: [
              (AppTheme.light, l10n.themeLight),
              (AppTheme.dark, l10n.themeDark),
              (AppTheme.auto, l10n.themeAuto),
            ],
            selected: s.theme,
            onChanged: n.setTheme,
          ),
        ),
        _DisclosureRow(
          label: l10n.appDisplayFont,
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
            title: l10n.appFontPickerTitle,
            fonts: kAppFonts,
            selected: [s.appFont],
            multiSelect: false,
            onChanged: (fonts) => n.setAppFont(fonts.first),
          ),
        ),
        _ToggleRow(
          label: l10n.showTransliteration,
          subLabel: l10n.showTransliterationSub,
          value: s.showTransliteration,
          onChanged: n.setShowTransliteration,
        ),
        _ToggleRow(
          label: l10n.disableRootParallax,
          subLabel: l10n.disableRootParallaxSub,
          value: s.disableRootParallax,
          onChanged: n.setDisableRootParallax,
        ),
      ]),

      // ── Practice ─────────────────────────────────────────────────────────
      _SectionHeader(l10n.practiceSection),
      _SettingsGroup(children: [
        _DisclosureRow(
          label: l10n.reviewIntensityLabel,
          value: intensityLabel(s.reviewIntensity, l10n),
          onTap: () => _showIntensityPicker(context, s, n),
        ),
        _ToggleRow(
          label: l10n.dailyReminder,
          subLabel: l10n.dailyReminderSub,
          value: s.dailyReminder,
          onChanged: n.setDailyReminder,
        ),
        _DisclosureRow(
          label: l10n.reminderTimeLabel,
          value: s.reminderTime.format(context),
          onTap: () => _showTimePicker(context, s, n),
        ),
        _DisclosureRow(
          label: l10n.quizFont,
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
                    : l10n.fontsCount(s.quizFonts.length),
                style: const TextStyle(fontSize: 16, color: AppColors.inkSecondary),
              ),
            ],
          ),
          onTap: () => _pushFontPicker(
            context,
            title: l10n.quizFont,
            fonts: kQuizFonts,
            selected: s.quizFonts,
            multiSelect: true,
            onChanged: n.setQuizFonts,
          ),
        ),
      ]),

      // ── Audio ─────────────────────────────────────────────────────────────
      _SectionHeader(l10n.audioSection),
      _SettingsGroup(children: [
        _ToggleRow(
          label: l10n.autoplayAudio,
          subLabel: l10n.autoplayAudioSub,
          value: s.autoplayAudio,
          leadingIcon: _LeadIcon(icon: Icons.volume_up_rounded, color: const Color(0xFFFF2D55)),
          onChanged: n.setAutoplayAudio,
        ),
        _ToggleRow(
          label: l10n.wifiOnlyDownloads,
          value: s.wifiOnlyDownloads,
          leadingIcon: _LeadIcon(icon: Icons.wifi_rounded, color: const Color(0xFF5B9BFF)),
          onChanged: n.setWifiOnlyDownloads,
        ),
      ]),

      // ── Storage & sync ────────────────────────────────────────────────────
      _SectionHeader(l10n.storageSyncSection),
      _SettingsGroup(children: [
        _DisclosureRow(
          label: l10n.syncNow,
          subLabel: _syncSubLabel(s.lastSyncedAt, l10n),
          leadingIcon: _LeadIcon(icon: Icons.sync_rounded, color: const Color(0xFF34C759)),
          onTap: () => _openSync(context),
        ),
        _ValueRow(
          label: l10n.dictionaryLabel,
          value: '48.2 MB',
          leadingIcon: _LeadIcon(icon: Icons.storage_rounded, color: const Color(0xFF5B9BFF)),
        ),
        _ValueRow(
          label: l10n.audioCacheLabel,
          value: '112 MB',
          leadingIcon: _LeadIcon(icon: Icons.access_time_rounded, color: const Color(0xFFFF9F0A)),
        ),
        _ActionRow(
          label: l10n.clearAudioCache,
          destructive: true,
          leadingIcon: _LeadIcon(icon: Icons.delete_outline_rounded, color: const Color(0xFFFF3B30)),
          onTap: () {/* TODO: clear audio cache */},
        ),
        _DisclosureRow(
          label: ignoredLabel,
          leadingIcon: _LeadIcon(icon: Icons.visibility_off_rounded, color: const Color(0xFF8E8E93)),
          onTap: () {
            Navigator.of(context)
                .push(adaptivePageRoute(builder: (_) => const IgnoredWordsPage()))
                .then((_) {
              if (context.mounted) ref.invalidate(ignoredWordsCountProvider);
            });
          },
        ),
        _DisclosureRow(
          label: knownLabel,
          leadingIcon: _LeadIcon(icon: Icons.check_circle_outline_rounded, color: const Color(0xFF34C759)),
          onTap: () {
            Navigator.of(context)
                .push(adaptivePageRoute(builder: (_) => const KnownWordsPage()))
                .then((_) {
              if (context.mounted) ref.invalidate(knownWordsCountProvider);
            });
          },
        ),
      ]),

      // ── Reset (standalone) ────────────────────────────────────────────────
      const SizedBox(height: 18),
      _SettingsGroup(children: [
        _ActionRow(
          label: l10n.resetAllProgress,
          destructive: true,
          leadingIcon: _LeadIcon(icon: Icons.restart_alt_rounded, color: const Color(0xFFFF9500)),
          onTap: () => _confirmReset(context),
        ),
      ]),

      // ── About ─────────────────────────────────────────────────────────────
      _SectionHeader(l10n.aboutSection),
      _SettingsGroup(children: [
        _DisclosureRow(
          label: l10n.rateApp,
          leadingIcon: _LeadIcon(icon: Icons.star_rounded, color: const Color(0xFFFFCC00)),
          onTap: () {/* TODO */},
        ),
        _DisclosureRow(
          label: l10n.sendFeedback,
          leadingIcon: _LeadIcon(icon: Icons.chat_bubble_rounded, color: const Color(0xFF34C759)),
          onTap: () {/* TODO */},
        ),
        _DisclosureRow(
          label: l10n.privacyPolicy,
          leadingIcon: _LeadIcon(icon: Icons.lock_rounded, color: const Color(0xFF8E8E93)),
          onTap: () {/* TODO */},
        ),
        _DisclosureRow(
          label: l10n.fontLicenses,
          leadingIcon: _LeadIcon(icon: Icons.description_rounded, color: const Color(0xFF5B9BFF)),
          onTap: () {/* TODO */},
        ),
      ]),

      Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        child: Text(
          l10n.appVersionFooter,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFFAEAEB2)),
        ),
      ),
    ];
  }

  String _syncSubLabel(DateTime? lastSynced, AppLocalizations l10n) {
    if (lastSynced == null) return l10n.neverSynced;
    final now = DateTime.now();
    final diff = now.difference(lastSynced);
    if (diff.inMinutes < 1) return l10n.lastSyncedJustNow;
    if (diff.inHours < 1) return l10n.lastSyncedMinutesAgo(diff.inMinutes);
    if (diff.inDays == 0) return l10n.lastSyncedTodayAt(_formatTime(lastSynced));
    final months = [
      l10n.monthJan, l10n.monthFeb, l10n.monthMar, l10n.monthApr,
      l10n.monthMay, l10n.monthJun, l10n.monthJul, l10n.monthAug,
      l10n.monthSep, l10n.monthOct, l10n.monthNov, l10n.monthDec,
    ];
    return l10n.lastSyncedOnDate(months[lastSynced.month - 1], lastSynced.day);
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
    final l10n = AppLocalizations.of(context)!;
    final picked = await showAdaptiveOptionPicker<AppLanguage>(
      context,
      title: l10n.languageLabel,
      current: s.language,
      options: [
        for (final l in AppLanguage.values) (l, l.label(l10n)),
      ],
    );
    if (picked != null) n.setLanguage(picked);
  }

  Future<void> _showIntensityPicker(BuildContext context, AppSettings s, SettingsNotifier n) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showAdaptiveOptionPicker<ReviewIntensity>(
      context,
      title: l10n.reviewIntensityLabel,
      current: s.reviewIntensity,
      options: ReviewIntensity.values.map((v) => (v, intensityLabel(v, l10n))).toList(),
    );
    if (picked == null) return;
    try {
      await n.setReviewIntensity(picked);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.couldNotSaveIntensity)),
      );
    }
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdaptiveConfirmDialog(
      context,
      title: l10n.resetProgressTitle,
      message: l10n.resetProgressMessage,
      destructiveLabel: l10n.resetProgressConfirm,
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 80),
                  child: Text(
                    AppLocalizations.of(context)!.settingsSheetTitle,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.ink),
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
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.done,
                      style: const TextStyle(
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


