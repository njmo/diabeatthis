import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'day_ai_sheet.dart';

class DayAiButton extends StatelessWidget {
  final DateTime date;
  const DayAiButton({super.key, required this.date});

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: context.lang.dayAiTitle,
    icon: const Icon(Icons.auto_awesome),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          FractionallySizedBox(heightFactor: .9, child: DayAiSheet(date: date)),
    ),
  );
}
