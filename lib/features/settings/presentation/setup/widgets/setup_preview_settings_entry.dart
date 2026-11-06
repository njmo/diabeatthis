import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../setup_wizard_preview_page.dart';

class SetupPreviewSettingsEntry extends StatelessWidget {
  const SetupPreviewSettingsEntry({super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
      title: Text(context.lang.setupPreviewEntry),
      subtitle: Text(context.lang.setupPreviewEntryDescription),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SetupWizardPreviewPage()),
      ),
    ),
  );
}
