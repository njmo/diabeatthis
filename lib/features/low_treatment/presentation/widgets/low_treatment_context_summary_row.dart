import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class LowTreatmentContextSummaryRow extends StatelessWidget {
  const LowTreatmentContextSummaryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.automatic = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool automatic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (automatic)
                    Text(
                      context.lang.lowTreatmentAutomatic,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
