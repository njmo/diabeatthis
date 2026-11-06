import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'family_planning_page.dart';

class FamilyPlanningEntry extends StatelessWidget {
  const FamilyPlanningEntry({super.key});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(16),
    child: ListTile(
      leading: const Icon(Icons.family_restroom),
      title: Text(context.lang.familyPlanTitle),
      subtitle: Text(context.lang.familyPlanEntryDescription),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FamilyPlanningPage()),
      ),
    ),
  );
}
