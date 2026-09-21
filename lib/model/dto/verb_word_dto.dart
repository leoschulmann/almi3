class VerbWordDto {
  final int id;
  final String value;
  final String translation;
  // True when [translation] was resolved on a fallback language rather than
  // the one requested.
  final bool isFallback;

  const VerbWordDto({
    required this.id,
    required this.value,
    required this.translation,
    this.isFallback = false,
  });
}
