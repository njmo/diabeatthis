import 'package:flutter/material.dart';

import '../theme/application_accent_colors.dart';
import 'detail_date_accent_painter.dart';

/// Shared typography and alignment for identity-header facts.
class DetailMetadataRow extends StatelessWidget {
  final String label;
  final IconData? icon;

  const DetailMetadataRow({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ApplicationAccentColors.warm(theme.brightness);
    return Row(
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 28,
            child: icon == null
                ? CustomPaint(
                    size: const Size(28, 14),
                    painter: DetailDateAccentPainter(accent),
                  )
                : Icon(icon, size: 20, color: accent),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
