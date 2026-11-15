import 'package:almi3/core/app_colors.dart';
import 'package:almi3/l10n/app_localizations.dart';
import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/lexeme_selection.dart' show entityTypeVerb;
import 'package:almi3/model/fsrs/lexeme_status_actions.dart';
import 'package:almi3/model/repository/user/answer_log_repository.dart';
import 'package:almi3/model/repository/user/lexeme_progress_repository.dart';
import 'package:almi3/viewmodel/session_notifier.dart' show contentLangProvider;
import 'package:almi3/viewmodel/sync_viewmodel.dart' show verbRepositoryProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _WordRow {
  final LexemeProgressTableData progress;
  final String label;

  const _WordRow({required this.progress, required this.label});
}

/// "Известные слова" (§10): lexemes with at least one assertKnown log still
/// on one of their cards. "Вернуть в изучение" here is
/// [LexemeStatusActionsService.resetKnownToNew] -- NOT undoMarkKnown, which
/// needs an in-memory snapshot that doesn't survive to a separate screen.
class KnownWordsPage extends ConsumerStatefulWidget {
  const KnownWordsPage({super.key});

  @override
  ConsumerState<KnownWordsPage> createState() => _KnownWordsPageState();
}

class _KnownWordsPageState extends ConsumerState<KnownWordsPage> {
  late Future<List<_WordRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_WordRow>> _load() async {
    final answerLogRepository = ref.read(answerLogRepositoryProvider);
    final lexemeProgressRepository = ref.read(lexemeProgressRepositoryProvider);
    final verbRepo = ref.read(verbRepositoryProvider);

    final ids = await answerLogRepository.getLexemeProgressIdsWithAssertKnownLog();

    final lang = ref.read(contentLangProvider);
    final result = <_WordRow>[];
    for (final id in ids) {
      final progress = await lexemeProgressRepository.getById(id);
      if (progress == null || progress.entityType != entityTypeVerb) continue;
      final detail = await verbRepo.getVerbDetail(progress.entityId, lang);
      if (detail == null) continue;
      final translation = detail.translations.isNotEmpty ? detail.translations.first : '';
      final label = translation.isEmpty ? detail.value : '${detail.value} — $translation';
      result.add(_WordRow(progress: progress, label: label));
    }
    return result;
  }

  Future<void> _returnToLearning(int lexemeProgressId) async {
    final service = ref.read(lexemeStatusActionsServiceProvider);
    await service.resetKnownToNew(lexemeProgressId);
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        elevation: 0,
        title: Text(l10n.knownWordsTitle),
      ),
      body: SafeArea(
        child: FutureBuilder<List<_WordRow>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _WordsErrorState();
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return Center(
                child: Text(
                  l10n.noKnownWords,
                  style: const TextStyle(fontSize: 16, color: AppColors.inkSecondary),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final row = rows[index];
                return _WordListTile(
                  label: row.label,
                  onReturn: () => _returnToLearning(row.progress.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Shared error state for both status-list pages -- same copy/style as
/// SessionPage's/PracticePage's `_ErrorState`.
class _WordsErrorState extends StatelessWidget {
  const _WordsErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.genericErrorMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
      ),
    );
  }
}

/// Shared row layout for both status-list pages: label + "Вернуть в изучение".
class _WordListTile extends StatelessWidget {
  final String label;
  final VoidCallback onReturn;

  const _WordListTile({required this.label, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: onReturn, child: Text(AppLocalizations.of(context)!.returnToLearning)),
        ],
      ),
    );
  }
}
