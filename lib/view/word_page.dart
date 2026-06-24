import 'package:almi3/model/dto/root_dto.dart';
import 'package:almi3/view/verb_page.dart';
import 'package:almi3/view/widgets/niqqud_btn.dart';
import 'package:almi3/view/widgets/word_chip.dart';
import 'package:almi3/viewmodel/state/word_page_state.dart';
import 'package:almi3/viewmodel/word_page_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums.dart';

class WordPage extends ConsumerWidget {
  final RootDto root;

  const WordPage({super.key, required this.root});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WordPageState state = ref.watch(wordPageProvider(root.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          root.value,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
        ),
        centerTitle: true,
        actions: const [NiqqudBtn()],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, WordPageState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errMsg != null) {
      return Center(
        child: Text('Error: ${state.errMsg}', style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    if (state.words.isEmpty) {
      return Center(
        child: Text('No words for this root yet.', style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 10,
          children: state.words.map((w) {
            return WordChip(
              hebrewText: w.value,
              translation: w.translation,
              type: WordType.verb,
              isBookmarked: state.isBookmarked(w.id),
              onBookmarkToggle: () =>
                  ref.read(wordPageProvider(root.id).notifier).toggleBookmark(w.id),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VerbPage(verbId: w.id, rootValue: root.value),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
