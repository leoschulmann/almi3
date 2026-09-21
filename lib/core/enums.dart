import 'package:almi3/core/app_colors.dart';
import 'package:flutter/material.dart';

enum GrammaticalPerson { none, first, second, third }

enum GrammaticalGender { none, masculine, feminine }

enum Plurality { singular, plural, none }

enum Tense {
  present('Present'),
  past('Past'),
  future('Future'),
  imperative('Imperative'),
  infinitive('Infinitive');

  const Tense(this.label);
  final String label;
}

const kTenseDisplayOrder = [
  Tense.infinitive,
  Tense.present,
  Tense.past,
  Tense.future,
  Tense.imperative,
];

enum BookmarkType { root, verb, noun, adjective, verbForm }

enum WordType {
  verb(
    gradientStart: AppColors.verbMain,
    gradientEnd: AppColors.verbGradient,
    textColor: AppColors.verbComplement,
  ),
  noun(
    gradientStart: AppColors.nounMain,
    gradientEnd: AppColors.nounGradient,
    textColor: AppColors.nounComplement,
  ),
  adjective(
    gradientStart: AppColors.adjectiveMain,
    gradientEnd: AppColors.adjectiveGradient,
    textColor: AppColors.adjectiveComplement,
  );

  const WordType({
    required this.gradientStart,
    required this.gradientEnd,
    required this.textColor,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color textColor;
}

Tense tenseFromJson(int i) => Tense.values[i];

GrammaticalPerson personFromJson(int i) => GrammaticalPerson.values[i];

Plurality pluralityFromJson(int i) => Plurality.values[i];

GrammaticalGender genderFromJson(int i) => GrammaticalGender.values[i];

/// `dbCode` is the sole source of the uppercase `lang` value stored in
/// content tables (e.g. `verb_t9n_table.lang`) -- never uppercase
/// `AppLanguage.name` ad hoc, always go through this field.
enum AppLanguage {
  en(dbCode: 'EN'),
  ru(dbCode: 'RU');

  const AppLanguage({required this.dbCode});
  final String dbCode;

  String get label => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.ru => 'Russian',
      };

  Locale get locale => Locale(name);
}

enum AppTheme { light, dark, auto }

enum ReviewIntensity { relaxed, normal, intense }

/// Shared human-readable label for review intensity, used by both
/// onboarding_page.dart and settings_page.dart -- one source, no second
/// hardcoded copy. Never surfaces the underlying desired_retention number.
String intensityLabel(ReviewIntensity v) {
  switch (v) {
    case ReviewIntensity.relaxed:
      return 'Relaxed';
    case ReviewIntensity.normal:
      return 'Normal';
    case ReviewIntensity.intense:
      return 'Intense';
  }
}

/// Reserved sentinel for the single hardcoded debug deck covering all
/// content, used until real `deck`/`deck_verb` schema exists (§9.1 defers
/// semantic decks). Negative so it can never collide with a future real
/// `deck` table PK (which would start at 1 via autoincrement).
const int kDefaultDeckId = -1;
