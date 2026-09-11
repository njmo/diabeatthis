import 'package:flutter/material.dart';

import '../../../../common/widgets/data_warning_indicator.dart';

class DaySummaryCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<String> warnings;
  const DaySummaryCard({
    super.key,
    required this.title,
    required this.children,
    this.warnings = const [],
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
