import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'family_management_page.dart';

class FamilySettingsSection extends StatelessWidget {
  const FamilySettingsSection({super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.people_outline),
      title: Text(context.lang.familyManagementTitle),
      subtitle: Text(context.lang.familySettingsDescription),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FamilyManagementPage()),
      ),
    ),
  );
}
