import 'package:flutter/material.dart';

class ActivityUpcomingSessionsView extends StatelessWidget {
  const ActivityUpcomingSessionsView({
    super.key,
    required this.entries,
    required this.emptyLabel,
  });
  final List<Widget> entries;
  final String emptyLabel;
  @override
  Widget build(BuildContext context) => entries.isEmpty
      ? Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyLabel, textAlign: TextAlign.center),
        )
      : ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: entries,
        );
}
