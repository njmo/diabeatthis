import 'package:flutter/material.dart';

import '../../l10n/language.dart';

class FamilyActivityLogCard extends StatelessWidget {
  const FamilyActivityLogCard({
    super.key,
    required this.payload,
    required this.name,
  });
  final Map payload;
  final String name;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.directions_run),
      title: Text(name),
      subtitle: Text(
        '${DateTime.fromMillisecondsSinceEpoch(payload['started_at'] as int).toLocal()} · ${payload['ended_at'] == null ? context.lang.familyPlanInProgress : context.lang.familyPlanCompleted}${payload['notes'] == null ? '' : '\n${payload['notes']}'}',
      ),
    ),
  );
}
