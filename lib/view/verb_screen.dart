import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/core/icon_assets.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/view/example_screen.dart';
import 'package:almi3/view/widgets/binyan_named_icon.dart';
import 'package:almi3/view/widgets/niqqud_btn.dart';
import 'package:almi3/view/widgets/verb_tense_section.dart';
import 'package:almi3/view/widgets/word_title.dart';
import 'package:almi3/viewmodel/state/verb_screen_state.dart';
import 'package:almi3/viewmodel/verb_screen_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class VerbScreen extends ConsumerWidget {
  final int verbId;
  final String rootValue;

  const VerbScreen({super.key, required this.verbId, required this.rootValue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verbScreenProvider(verbId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'verb - $rootValue',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        actions: const [NiqqudBtn()],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, VerbScreenState state) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.errMsg != null) return Center(child: Text('Error: ${state.errMsg}'));
    final verb = state.verb;
    if (verb == null) return const Center(child: Text('Not found'));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MainSection(verb: verb),
          ..._buildTenseSections(context, ref, state, verb),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildTenseSections(BuildContext context, WidgetRef ref, VerbScreenState state, VerbDetailDto verb) {
    final formsByTense = <Tense, List<VerbFormDisplayDto>>{};
    for (final f in verb.forms) {
      formsByTense.putIfAbsent(f.tense, () => []).add(f);
    }

    return kTenseDisplayOrder
        .where((t) => formsByTense.containsKey(t))
        .map((t) => VerbTenseSection(
              label: t.label,
              tense: t,
              forms: formsByTense[t]!,
              onChipTap: (form) => _onChipTap(context, verb, form),
              isFormBookmarked: (formId) => state.isFormBookmarked(formId),
              onFormBookmarkToggle: (formId) =>
                  ref.read(verbScreenProvider(verbId).notifier).toggleFormBookmark(formId),
            ))
        .toList();
  }

  void _onChipTap(BuildContext context, VerbDetailDto verb, VerbFormDisplayDto form) {
    // Check if this verb has any examples at all — we don't know per-form yet
    // without an extra query, so we navigate and let the screen handle empty state.
    // For a snackbar on zero examples we rely on ExampleScreen itself.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExampleScreen(
          verbId: verbId,
          verbValue: verb.value,
          focusedFormId: form.id,
        ),
      ),
    );
  }
}

class _MainSection extends StatelessWidget {
  final VerbDetailDto verb;

  const _MainSection({required this.verb});

  @override
  Widget build(BuildContext context) {
    final meta = [verb.root, ...verb.gizrahs, ...verb.preps].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 72,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  //todo move to widget
                  child: SvgPicture.asset(heartIconAsset(0), width: 42, height: 36),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: BinyanNamedIcon(binyanName: verb.binyan),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: GoogleFonts.rubik(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          WordTitle(translations: verb.translations, hebrewValue: verb.value, wordType: WordType.verb),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
