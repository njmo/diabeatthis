import 'package:flutter/material.dart';

/// Compact portion entry with an explicit review checkbox and optional details.
class PortionReviewRow extends StatelessWidget {
  const PortionReviewRow({
    super.key,
    required this.name,
    required this.summary,
    required this.amountField,
    required this.reviewed,
    required this.reviewLabel,
    required this.onReviewed,
    required this.detailsLabel,
    required this.onDetails,
  });
  final String name;
  final String summary;
  final Widget amountField;
  final bool reviewed;
  final String reviewLabel;
  final ValueChanged<bool?>? onReviewed;
  final String detailsLabel;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        value: reviewed,
        onChanged: onReviewed,
        checkboxSemanticLabel: '$reviewLabel: $name',
        title: Text(name, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                summary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              onPressed: onDetails,
              tooltip: detailsLabel,
              icon: const Icon(Icons.info_outline, size: 18),
            ),
          ],
        ),
        secondary: SizedBox(width: 88, child: amountField),
      ),
      const Divider(height: 1),
    ],
  );
}
