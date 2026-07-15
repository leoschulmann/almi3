import 'package:flutter/material.dart';

import 'enums.dart';

class AppSettings {
  final AppLanguage language;
  final AppTheme theme;
  final String appFont;
  final List<String> quizFonts;
  final bool showTransliteration;
  final bool disableRootParallax;
  final ReviewIntensity reviewIntensity;
  final int dayBoundaryHour;
  final int newCardsPerDay;
  final List<int> activeDeckIds;
  final bool dailyReminder;
  final TimeOfDay reminderTime;
  final bool autoplayAudio;
  final bool wifiOnlyDownloads;
  final DateTime? lastSyncedAt;

  const AppSettings({
    required this.language,
    required this.theme,
    required this.appFont,
    required this.quizFonts,
    required this.showTransliteration,
    required this.disableRootParallax,
    required this.reviewIntensity,
    required this.dayBoundaryHour,
    required this.newCardsPerDay,
    required this.activeDeckIds,
    required this.dailyReminder,
    required this.reminderTime,
    required this.autoplayAudio,
    required this.wifiOnlyDownloads,
    required this.lastSyncedAt,
  });

  AppSettings copyWith({
    AppLanguage? language,
    AppTheme? theme,
    String? appFont,
    List<String>? quizFonts,
    bool? showTransliteration,
    bool? disableRootParallax,
    ReviewIntensity? reviewIntensity,
    int? dayBoundaryHour,
    int? newCardsPerDay,
    List<int>? activeDeckIds,
    bool? dailyReminder,
    TimeOfDay? reminderTime,
    bool? autoplayAudio,
    bool? wifiOnlyDownloads,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
  }) {
    return AppSettings(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      appFont: appFont ?? this.appFont,
      quizFonts: quizFonts ?? this.quizFonts,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      disableRootParallax: disableRootParallax ?? this.disableRootParallax,
      reviewIntensity: reviewIntensity ?? this.reviewIntensity,
      dayBoundaryHour: dayBoundaryHour ?? this.dayBoundaryHour,
      newCardsPerDay: newCardsPerDay ?? this.newCardsPerDay,
      activeDeckIds: activeDeckIds ?? this.activeDeckIds,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      autoplayAudio: autoplayAudio ?? this.autoplayAudio,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      lastSyncedAt: clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
    );
  }

  static AppSettings defaultSettings() {
    return AppSettings(
      language: WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ru'
        ? AppLanguage.ru
        : AppLanguage.en,
      theme: AppTheme.auto,
      appFont: kAppFonts.first,
      quizFonts: [kQuizFonts.first],
      showTransliteration: true,
      disableRootParallax: false,
      reviewIntensity: ReviewIntensity.normal,
      dayBoundaryHour: 4,
      newCardsPerDay: 10,
      // Empty = unrestricted (all decks); semantic decks aren't implemented
      // yet (§9.1), so this has no effect until deck membership queries exist.
      activeDeckIds: const [],
      dailyReminder: true,
      reminderTime: const TimeOfDay(hour: 9, minute: 0),
      autoplayAudio: true,
      wifiOnlyDownloads: true,
      lastSyncedAt: null,
    );
  }
}

const List<String> kAppFonts = [
  'Noto Sans Hebrew',
  'Frank Ruhl Libre',
];

const List<String> kQuizFonts = [
  'Noto Sans Hebrew',
  'Frank Ruhl Libre',
  'David Libre',
  'Noto Serif Hebrew',
  'Secular One',
  'Suez One',
  'Gveret Levin',
];

const Map<String, String> kFontTags = {
  'Noto Sans Hebrew': 'Sans · default',
  'Frank Ruhl Libre': 'Serif · literary',
  'David Libre': 'Serif · classic print',
  'Noto Serif Hebrew': 'Serif · newspaper',
  'Secular One': 'Display · bold',
  'Suez One': 'Display · heavy',
  'Gveret Levin': 'Handwritten · cursive',
};
