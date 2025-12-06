import 'package:almi3/core/logger.dart';
import 'package:almi3/model/dto/root_dto.dart';
import 'package:almi3/viewmodel/reference_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReferencePage extends ConsumerWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageState = ref.watch(referencePageProvider);
    logger.d('ReferencePage build: roots=${pageState.roots.length}, isLoading=${pageState.isLoading}, hasMore=${pageState.hasMore}');

    if (pageState.isLoading && pageState.roots.isEmpty) {
      logger.d('ReferencePage: showing loading state');
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Reference'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (pageState.errMsg != null) {
      logger.w('ReferencePage: showing error: ${pageState.errMsg}');
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Reference'),
        ),
        body: Center(
          child: Text('Error: ${pageState.errMsg}', style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }

    if (pageState.roots.isEmpty) {
      logger.d('ReferencePage: showing empty state');
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Reference'),
        ),
        body: Center(child: Text('Empty :(', style: Theme.of(context).textTheme.bodyLarge)),
      );
    }

    logger.i('ReferencePage: showing list with ${pageState.roots.length} items');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Reference'),
      ),
      body: RefreshIndicator(
              onRefresh: () => ref.read(referencePageProvider.notifier).refresh(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final ScrollMetrics metrics = notification.metrics;
                  if (metrics.pixels > metrics.maxScrollExtent * 0.8) {
                    ref.read(referencePageProvider.notifier).loadMore();
                  }
                  return false;
                },

                child: ListView.builder(
                  itemCount: pageState.roots.length + (pageState.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == pageState.roots.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    RootDto root = pageState.roots[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${root.id}')),
                      title: Text(root.value),
                      subtitle: Text('v${root.version}'),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
