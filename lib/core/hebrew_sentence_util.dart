// ־ = maqaf (U+05BE), ׳ = geresh (U+05F3), ״ = gershayim (U+05F4)
final _punctRegex = RegExp(
    '(^[\\u05BE\\u05F3\\u05F4\\s,.:;!?()\\[\\]"\']+'
    '|[\\u05BE\\u05F3\\u05F4\\s,.:;!?()\\[\\]"\']+\$)');

String stripHebrewPunct(String token) => token.replaceAll(_punctRegex, '');

/// Returns the index of the token in [sentence] (split by spaces) whose
/// de-punctuated form equals [formValue], or -1 if not found.
int findFormTokenIndex(String sentence, String formValue) {
  final tokens = sentence.split(' ');
  return tokens.indexWhere((t) => stripHebrewPunct(t) == formValue);
}

/// Picks the Hebrew spelling to show: the ktiv male one (no niqqud, computed
/// by the server) when niqqud is switched off, otherwise the voweled text.
/// Falls back to the voweled text while the server has not computed [ktivMale].
///
/// The niqqud quiz (QuizType.niqqud) is about the vowels themselves: it must
/// pass `showNiqqud: true` regardless of the user's setting.
String hebrewText(String voweled, String? ktivMale, bool showNiqqud) =>
    showNiqqud ? voweled : (ktivMale ?? voweled);
