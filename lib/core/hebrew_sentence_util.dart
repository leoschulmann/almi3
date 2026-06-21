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
