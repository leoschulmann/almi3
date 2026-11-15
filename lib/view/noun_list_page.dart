import 'package:almi3/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class NounListPage extends StatelessWidget {
  const NounListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(l10n.nounsTitle),
      ),
      body: Center(child: Text(l10n.nounsPageBody)),
    );
  }
}
