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
