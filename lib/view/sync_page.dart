import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodel/state/sync_page_state.dart';
import '../viewmodel/sync_viewmodel.dart';

class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncViewmodelState state = ref.watch(rootViewmodelProvider);
    final SyncViewmodelNotifier notifier = ref.read(rootViewmodelProvider.notifier);

    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: const Text('Sync')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status/Loader area
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: _buildStatusContent(context, state)),
              ),
              const SizedBox(height: 48),
              // Synchronize button
              ElevatedButton(
                onPressed: state.isLoading ? null : () => notifier.fetchAndInsertFromApi(),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24)),
                child: const Text('Synchronize', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusContent(BuildContext context, SyncViewmodelState state) {
    if (state.isLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Synchronizing...', style: Theme.of(context).textTheme.bodyLarge),
        ],
      );
    }

    if (state.errMsg != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(state.errMsg ?? '', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ),
        ],
      );
    }

    if (state.total > 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Icon(Icons.check_circle_outline, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Successfully synchronized', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _buildStatRow(context, 'Inserted:', state.inserted),
          _buildStatRow(context, 'Updated:', state.updated),
          _buildStatRow(context, 'Skipped:', state.skipped),
          const SizedBox(height: 8),
          Text(
            'Total: ${state.total} items',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Text('Ready to synchronize', style: Theme.of(context).textTheme.bodyLarge);
  }

  Widget _buildStatRow(BuildContext context, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
