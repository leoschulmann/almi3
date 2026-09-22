import 'package:almi3/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class VerbListPage extends StatelessWidget {
  const VerbListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(l10n.verbsTitle),
      ),
      body: Center(child: Text(l10n.verbsPageBody)),
    );
  }
}
