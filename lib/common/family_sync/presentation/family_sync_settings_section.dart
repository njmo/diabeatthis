import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'family_sync_page.dart';

class FamilySyncSettingsSection extends StatelessWidget {
  const FamilySyncSettingsSection({super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.sync),
      title: Text(context.lang.familySyncTitle),
      subtitle: Text(context.lang.familySyncDescription),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const FamilySyncPage())),
    ),
  );
}
