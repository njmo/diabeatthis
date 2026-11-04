import 'package:flutter/material.dart';

import '../theme/application_accent_colors.dart';
import 'detail_metadata_row.dart';

/// Shared identity layout for meal, ingredient, activity and history previews.
class DetailIdentityHeader extends StatelessWidget {
  const DetailIdentityHeader({
    super.key,
    required this.title,
    required this.status,
    required this.dateLabel,
    this.statusColor,
    this.dateIcon,
    this.titleAction,
    this.child,
  });
  final String title;
  final String status;
  final String dateLabel;
  final Color? statusColor;
  final IconData? dateIcon;
  final Widget? titleAction;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ApplicationAccentColors.warm(theme.brightness);
    final titleText = Text(
      title,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -.4,
      ),
    );
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
          if (titleAction == null)
            titleText
          else
            Row(
              children: [
                Expanded(child: titleText),
                const SizedBox(width: 12),
                titleAction!,
              ],
            ),
          const SizedBox(height: 16),
          DetailMetadataRow(label: dateLabel, icon: dateIcon),
          if (child != null) ...[const SizedBox(height: 8), child!],
        ],
      ),
    );
  }
}
