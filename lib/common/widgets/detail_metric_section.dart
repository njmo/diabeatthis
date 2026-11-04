import 'package:flutter/material.dart';

import 'responsive_metric_list.dart';
import 'summary_detail_card.dart';

class DetailMetricSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> metrics;
  final List<Widget> children;

  const DetailMetricSection({
    super.key,
    required this.title,
    required this.icon,
    required this.metrics,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SummaryDetailCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveMetricList(
            maxColumns: 2,
            equalRowHeights: true,
            children: metrics,
          ),
          if (children.isNotEmpty) ...[const SizedBox(height: 12), ...children],
        ],
      ),
    );
  }
}
