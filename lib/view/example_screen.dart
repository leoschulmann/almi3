import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/enums.dart';
import 'package:almi3/model/dto/example_display_dto.dart';
import 'package:almi3/view/widgets/example_form_section.dart';
import 'package:almi3/view/widgets/niqqud_btn.dart';
import 'package:almi3/view/widgets/tense_section_header.dart';
import 'package:almi3/view/widgets/verb_tense_section.dart';
import 'package:almi3/viewmodel/example_screen_viewmodel.dart';
import 'package:almi3/viewmodel/state/example_screen_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class ExampleScreen extends ConsumerStatefulWidget {
  final int verbId;
  final String verbValue;
  final int? focusedFormId;

  const ExampleScreen({super.key, required this.verbId, required this.verbValue, this.focusedFormId});

  @override
  ConsumerState<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends ConsumerState<ExampleScreen> {
  final _scrollController = ScrollController();
  final _formKeys = <int, GlobalKey>{};
  bool _focusHandled = false;
  late ScaffoldMessengerState _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messenger.hideCurrentSnackBar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fid = widget.focusedFormId;

    ref.listen(exampleScreenProvider(widget.verbId), (ExampleScreenState? prev, ExampleScreenState next) {
      if (next.isLoading || next.errMsg != null) return;
      if (fid == null || _focusHandled) return;
      _focusHandled = true;

      if (!next.groups.any((g) => g.formId == fid)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No examples for this form yet')));
        });
        return;
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _scrollToForm(fid);
      });
    });

    final state = ref.watch(exampleScreenProvider(widget.verbId));

    // Handle already-loaded case: provider was cached, listener won't fire.
    if (!state.isLoading && state.errMsg == null && fid != null && !_focusHandled) {
      _focusHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!state.groups.any((g) => g.formId == fid)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No examples for this form yet')));
        } else {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _scrollToForm(fid);
          });
        }
      });
    }

    final total = state.groups.fold(0, (sum, g) => sum + g.examples.length);

    return Scaffold(
      appBar: AppBar(
        title: Text('examples for ($total) ${widget.verbValue}', style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        actions: const [NiqqudBtn()],
      ),
      body: _buildBody(state),
    );
  }

  void _scrollToForm(int formId) {
    final ctx = _formKeys[formId]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOut, alignment: 0.2);
  }

  Widget _buildBody(ExampleScreenState state) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.errMsg != null) return Center(child: Text('Error: ${state.errMsg}'));
    if (state.groups.isEmpty) {
      return Center(
        child: Text('No examples found', style: GoogleFonts.rubik(fontSize: 16, color: AppColors.textSecondary)),
      );
    }

    for (final g in state.groups) {
      _formKeys.putIfAbsent(g.formId, () => GlobalKey());
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [..._buildTenseSections(state.groups), const SizedBox(height: 32)],
      ),
    );
  }

  List<Widget> _buildTenseSections(List<VerbFormExampleGroupDto> groups) {
    final byTense = <Tense, List<VerbFormExampleGroupDto>>{};
    for (final g in groups) {
      byTense.putIfAbsent(g.tense, () => []).add(g);
    }

    final sections = <Widget>[];
    for (final Tense tense in kTenseDisplayOrder) {
      final List<VerbFormExampleGroupDto>? tenseGroups = byTense[tense];
      if (tenseGroups == null) continue;

      final sorted = _sortByTenseRowOrder(tenseGroups, tense);
      sections.add(TenseSectionHeader(label: tense.label));
      sections.add(const SizedBox(height: 12));
      for (final VerbFormExampleGroupDto group in sorted) {
        sections.add(
          Padding(
            key: _formKeys[group.formId],
            padding: const EdgeInsets.only(bottom: 16),
            child: ExampleFormSection(group: group, focused: group.formId == widget.focusedFormId),
          ),
        );
      }
    }
    return sections;
  }

  List<VerbFormExampleGroupDto> _sortByTenseRowOrder(List<VerbFormExampleGroupDto> groups, Tense tense) {
    final flat = tenseFormRows(tense).expand((row) => row).toList();
    int rank(VerbFormExampleGroupDto g) {
      final idx = flat.indexWhere((k) => k.person == g.person && k.plurality == g.plurality && k.gender == g.gender);
      return idx == -1 ? 999 : idx;
    }

    return [...groups]..sort((a, b) => rank(a).compareTo(rank(b)));
  }
}
