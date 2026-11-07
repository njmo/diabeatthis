import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/language.dart';
import '../../presentation/widgets/activity_log_card.dart';

/// Cloud adapter; rendering is shared with the child's local history.
class FamilyActivityLogCard extends StatelessWidget {
  const FamilyActivityLogCard({
    super.key,
    required this.payload,
    required this.name,
  });
  final Map payload;
  final String name;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          DateFormat.yMd(context.lang.localeName).format(
            DateTime.fromMillisecondsSinceEpoch(
              payload['started_at'] as int,
            ).toLocal(),
          ),
        ),
      ),
      ActivityLogCard(
        name: name,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          payload['started_at'] as int,
        ),
        endedAt: payload['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(payload['ended_at'] as int),
        onTap: null,
      ),
      if (payload['notes'] != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(payload['notes'] as String),
        ),
    ],
  );
}
