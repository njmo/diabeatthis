import 'package:flutter/material.dart';

import '../theme/application_accent_colors.dart';
import 'detail_date_accent_painter.dart';

/// Shared identity layout for meal, ingredient, activity and history previews.
class DetailIdentityHeader extends StatelessWidget {
  const DetailIdentityHeader({
    super.key,
    required this.title,
    required this.status,
    required this.dateLabel,
    this.statusColor,
    this.child,
  });
  final String title;
  final String status;
  final String dateLabel;
  final Color? statusColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ApplicationAccentColors.warm(theme.brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.circle,
                  size: 10,
                  color: statusColor ?? accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: statusColor ?? accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ExcludeSemantics(
                child: CustomPaint(
                  size: const Size(28, 14),
                  painter: DetailDateAccentPainter(accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 8), child!],
        ],
      ),
    );
  }
}
