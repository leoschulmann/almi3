import '../model/dto/root_card_stats.dart';

class RootSummary {
  final String verdict;
  final String info;
  final String? pillText;

  const RootSummary({required this.verdict, required this.info, this.pillText});
}

class RootSummaryResolver {
  static RootSummary resolve(RootCardStats? stats) {
    if (stats == null || stats.totalWords == 0) {
      return const RootSummary(verdict: 'Not started', info: '');
    }

    final info = _buildInfo(stats);

    if (stats.totalDue > 0) {
      return RootSummary(
        verdict: 'Review needed',
        info: info,
        pillText: '${stats.totalDue} to review',
      );
    }

    if (stats.totalLearned == 0) {
      return RootSummary(verdict: 'Not started', info: info);
    }

    final ratio = stats.totalLearned / stats.totalWords;

    if (ratio < 0.3) {
      return RootSummary(verdict: 'Just getting started', info: info);
    } else if (ratio < 0.7) {
      return RootSummary(verdict: 'Keep practicing', info: info);
    } else if (ratio < 1.0) {
      return RootSummary(verdict: 'Looking good', info: info);
    } else {
      return RootSummary(verdict: 'Mastered', info: info);
    }
  }

  static String _buildInfo(RootCardStats s) {
    final parts = <String>[];
    if (s.verbs.total > 0) parts.add('${s.verbs.total} verb${s.verbs.total == 1 ? '' : 's'}');
    if (s.nouns.total > 0) parts.add('${s.nouns.total} noun${s.nouns.total == 1 ? '' : 's'}');
    if (s.adjs.total > 0) parts.add('${s.adjs.total} adj${s.adjs.total == 1 ? '' : 's'}');
    return parts.join(' · ');
  }
}
