import 'package:flutter/material.dart';

/// Compact, wrapping links to the evidence used by an AI analysis.
class AiInspectionLinks extends StatelessWidget {
  final List<({String label, IconData icon, VoidCallback? onPressed})> links;

  const AiInspectionLinks({super.key, required this.links});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final link in links)
          TextButton.icon(
            onPressed: link.onPressed,
            icon: Icon(link.icon, size: 18),
            label: Text(link.label),
          ),
      ],
    ),
  );
}
