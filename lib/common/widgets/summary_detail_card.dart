import 'package:flutter/material.dart';

import 'information_button.dart';
import 'section_surface.dart';

/// A detail surface with a colourful stage icon and optional detail navigation.
class SummaryDetailCard extends StatelessWidget {
  final String title;
  final String? explanation;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onDetails;
  final IconData icon;
  final Color? headerColor;
  final Color? headerForeground;

  const SummaryDetailCard({
    super.key,
    required this.title,
    this.explanation,
    required this.child,
    this.actionLabel,
    this.onDetails,
    this.icon = Icons.insights_rounded,
    this.headerColor,
    this.headerForeground,
  }) : assert(onDetails == null || actionLabel != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: headerColor ?? scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: headerForeground ?? scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (explanation != null)
                InformationButton(title: title, message: explanation!),
            ],
          ),
          const SizedBox(height: 16),
          child,
          if (onDetails != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(actionLabel!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
