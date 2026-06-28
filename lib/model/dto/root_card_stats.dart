class WordTypeStats {
  final int total;
  final int learned;
  final int due;

  const WordTypeStats({this.total = 0, this.learned = 0, this.due = 0});
}

class RootCardStats {
  final WordTypeStats verbs;
  final WordTypeStats nouns;
  final WordTypeStats adjs;

  const RootCardStats({
    this.verbs = const WordTypeStats(),
    this.nouns = const WordTypeStats(),
    this.adjs = const WordTypeStats(),
  });

  int get totalWords => verbs.total + nouns.total + adjs.total;
  int get totalLearned => verbs.learned + nouns.learned + adjs.learned;
  int get totalDue => verbs.due + nouns.due + adjs.due;
}
