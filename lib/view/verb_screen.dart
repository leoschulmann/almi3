import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/core/icon_assets.dart';
import 'package:almi3/model/dto/verb_detail_dto.dart';
import 'package:almi3/view/widgets/binyan_named_icon.dart';
import 'package:almi3/view/widgets/niqqud_btn.dart';
import 'package:almi3/view/widgets/verb_form_chip.dart';
import 'package:almi3/view/widgets/verb_tense_section.dart';
import 'package:almi3/view/widgets/word_title.dart';
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
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, state) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.errMsg != null) return Center(child: Text('Error: ${state.errMsg}'));
    final verb = state.verb;
    if (verb == null) return const Center(child: Text('Not found'));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MainSection(verb: verb),
          ..._buildTenseSections(verb),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildTenseSections(VerbDetailDto verb) {
    final formsByTense = <Tense, List<VerbFormDisplayDto>>{};
    for (final f in verb.forms) {
      formsByTense.putIfAbsent(f.tense, () => []).add(f);
    }

    const tenseOrder = [Tense.infinitive, Tense.present, Tense.past, Tense.future, Tense.imperative];
    const tenseLabels = {
      Tense.infinitive: 'Infinitive',
      Tense.present: 'Present',
      Tense.past: 'Past',
      Tense.future: 'Future',
      Tense.imperative: 'Imperative',
    };

    return tenseOrder
        .where((t) => formsByTense.containsKey(t))
        .map((t) => VerbTenseSection(
              label: tenseLabels[t]!,
              tense: t,
              forms: formsByTense[t]!,
            ))
        .toList();
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
