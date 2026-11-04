import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../data/model/copied_meal_type.dart';
import 'copied_meal_history_button.dart';

class CopiedMealPreviewHeader extends StatelessWidget {
  const CopiedMealPreviewHeader({
    super.key,
    required this.source,
    required this.onBack,
  });

  final CopiedMealType source;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BottomSheetStepHeader(
          title: context.lang.mealCompositionTitle,
          titleStyle: theme.textTheme.titleLarge,
          onBack: onBack,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                source.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMMd(
                        context.lang.localeName,
                      ).format(source.date),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (source is CopiedMealFromMeal)
                CopiedMealHistoryButton(source: source),
            ],
          ),
        ),
      ],
    );
  }
}
