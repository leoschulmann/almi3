import 'package:almi3/core/logger.dart';
import 'package:almi3/view/widgets/niqqud_btn.dart';
import 'package:almi3/view/widgets/root_card.dart';
import 'package:almi3/view/word_page.dart';
import 'package:almi3/viewmodel/reference_viewmodel.dart';
import 'package:almi3/viewmodel/state/reference_page_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReferencePage extends ConsumerWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReferencePageState pageState = ref.watch(referencePageProvider);
    logger.d('ReferencePage build: roots=${pageState.roots.length}, isLoading=${pageState.isLoading}');

    return Scaffold(
      appBar: _buildAppBar(context, pageState),
      body: _buildBody(context, ref, pageState),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ReferencePageState state) {
    final count = state.roots.length;
    return AppBar(
      title: Text(
        count > 0 ? 'Roots ($count)' : 'Roots',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      centerTitle: true,
      actions: const [NiqqudBtn()],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ReferencePageState state) {
    if (state.isLoading && state.roots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errMsg != null) {
      return Center(
        child: Text('Error: ${state.errMsg}', style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    if (state.roots.isEmpty) {
      return Center(
        child: Text('No roots — try syncing first.', style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SearchBar(
            hintText: 'Search',
            leading: const Icon(Icons.search),
            trailing: [const Icon(Icons.mic)],
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.06)),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) {/* search wired later */},
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(referencePageProvider.notifier).refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels > notification.metrics.maxScrollExtent * 0.8) {
                  ref.read(referencePageProvider.notifier).loadMore();
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: state.roots.length + (state.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.roots.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final root = state.roots[index];
                  return RootCard(
                    hebrewText: root.value,
                    adjCount: 0,
                    verbCount: 0,
                    nounCount: 0,
                    isBookmarked: state.isBookmarked(root.id),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => WordPage(root: root)),
                    ),
                    onBookmarkToggle: () =>
                        ref.read(referencePageProvider.notifier).toggleBookmark(root.id),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
