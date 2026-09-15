import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/data_warning_indicator.dart';

class DaySummaryCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<String> warnings;
  final String? information;
  const DaySummaryCard({
    super.key,
    required this.title,
    required this.children,
    this.warnings = const [],
    this.information,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (information != null)
                IconButton(
                  tooltip: context.lang.dayReviewDetails,
                  icon: const Icon(Icons.info_outline, size: 20),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    useSafeArea: true,
                    builder: (_) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Text(information!),
                    ),
                  ),
                ),
              if (warnings.isNotEmpty)
                DataWarningIndicator(message: warnings.join('\n')),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}
