import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../data/model/copied_meal_type.dart';

class CopiedMealPreviewHeader extends StatelessWidget {
  const CopiedMealPreviewHeader({
    super.key,
    required this.source,
    required this.onBack,
    required this.onUse,
  });

  final CopiedMealType source;
  final VoidCallback onBack;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BottomSheetStepHeader(
          title: context.lang.copiedMealPreview,
          onBack: onBack,
          actions: [
            FilledButton.icon(
              onPressed: onUse,
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: Text(context.lang.copiedMealUseIngredients),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                source.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(source.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
