import 'package:almi3/core/app_settings.dart';
import 'package:almi3/core/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Injected at app startup via ProviderScope override.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('SharedPreferences not injected'),
);

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _kLanguage = 'settings.language';
  static const _kTheme = 'settings.theme';
  static const _kAppFont = 'settings.appFont';
  static const _kQuizFonts = 'settings.quizFonts';
  static const _kShowTranslit = 'settings.showTransliteration';
  static const _kDisableParallax = 'settings.disableRootParallax';
  static const _kReviewIntensity = 'settings.reviewIntensity';
  static const _kDailyReminder = 'settings.dailyReminder';
  static const _kReminderHour = 'settings.reminderHour';
  static const _kReminderMinute = 'settings.reminderMinute';
  static const _kAutoplay = 'settings.autoplayAudio';
  static const _kWifiOnly = 'settings.wifiOnlyDownloads';
  static const _kLastSyncedAt = 'settings.lastSyncedAt';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() => _load();

  AppSettings _load() {
    final defaults = AppSettings.defaultSettings();
    final prefs = _prefs;

    final langStr = prefs.getString(_kLanguage);
    final lang = langStr != null
        ? AppLanguage.values.firstWhere((e) => e.name == langStr, orElse: () => defaults.language)
        : defaults.language;

    final themeStr = prefs.getString(_kTheme);
    final theme = themeStr != null
        ? AppTheme.values.firstWhere((e) => e.name == themeStr, orElse: () => defaults.theme)
        : defaults.theme;

    final intensityStr = prefs.getString(_kReviewIntensity);
    final intensity = intensityStr != null
        ? ReviewIntensity.values.firstWhere((e) => e.name == intensityStr, orElse: () => defaults.reviewIntensity)
        : defaults.reviewIntensity;

    final quizFonts = prefs.getStringList(_kQuizFonts) ?? defaults.quizFonts;
    final lastSyncMs = prefs.getInt(_kLastSyncedAt);

    return AppSettings(
      language: lang,
      theme: theme,
      appFont: prefs.getString(_kAppFont) ?? defaults.appFont,
      quizFonts: quizFonts.isEmpty ? defaults.quizFonts : quizFonts,
      showTransliteration: prefs.getBool(_kShowTranslit) ?? defaults.showTransliteration,
      disableRootParallax: prefs.getBool(_kDisableParallax) ?? defaults.disableRootParallax,
      reviewIntensity: intensity,
      dailyReminder: prefs.getBool(_kDailyReminder) ?? defaults.dailyReminder,
      reminderTime: TimeOfDay(
        hour: prefs.getInt(_kReminderHour) ?? defaults.reminderTime.hour,
        minute: prefs.getInt(_kReminderMinute) ?? defaults.reminderTime.minute,
      ),
      autoplayAudio: prefs.getBool(_kAutoplay) ?? defaults.autoplayAudio,
      wifiOnlyDownloads: prefs.getBool(_kWifiOnly) ?? defaults.wifiOnlyDownloads,
      lastSyncedAt: lastSyncMs != null ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs) : null,
    );
  }

  void _save(AppSettings s) {
    final prefs = _prefs;
    prefs.setString(_kLanguage, s.language.name);
    prefs.setString(_kTheme, s.theme.name);
    prefs.setString(_kAppFont, s.appFont);
    prefs.setStringList(_kQuizFonts, s.quizFonts);
    prefs.setBool(_kShowTranslit, s.showTransliteration);
    prefs.setBool(_kDisableParallax, s.disableRootParallax);
    prefs.setString(_kReviewIntensity, s.reviewIntensity.name);
    prefs.setBool(_kDailyReminder, s.dailyReminder);
    prefs.setInt(_kReminderHour, s.reminderTime.hour);
    prefs.setInt(_kReminderMinute, s.reminderTime.minute);
    prefs.setBool(_kAutoplay, s.autoplayAudio);
    prefs.setBool(_kWifiOnly, s.wifiOnlyDownloads);
    if (s.lastSyncedAt != null) {
      prefs.setInt(_kLastSyncedAt, s.lastSyncedAt!.millisecondsSinceEpoch);
    }
  }

  void _update(AppSettings Function(AppSettings) updater) {
    final next = updater(state);
    state = next;
    _save(next);
  }

  void setLanguage(AppLanguage v) => _update((s) => s.copyWith(language: v));
  void setTheme(AppTheme v) => _update((s) => s.copyWith(theme: v));
  void setAppFont(String v) => _update((s) => s.copyWith(appFont: v));
  void setQuizFonts(List<String> v) => _update((s) => s.copyWith(quizFonts: v));
  void setShowTransliteration(bool v) => _update((s) => s.copyWith(showTransliteration: v));
  void setDisableRootParallax(bool v) => _update((s) => s.copyWith(disableRootParallax: v));
  void setReviewIntensity(ReviewIntensity v) => _update((s) => s.copyWith(reviewIntensity: v));
  void setDailyReminder(bool v) => _update((s) => s.copyWith(dailyReminder: v));
  void setReminderTime(TimeOfDay v) => _update((s) => s.copyWith(reminderTime: v));
  void setAutoplayAudio(bool v) => _update((s) => s.copyWith(autoplayAudio: v));
  void setWifiOnlyDownloads(bool v) => _update((s) => s.copyWith(wifiOnlyDownloads: v));
  void recordSync() => _update((s) => s.copyWith(lastSyncedAt: DateTime.now()));
}
