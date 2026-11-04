import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/copied_meal_provider.dart';
import '../screens/meal_page.dart';

class CopiedMealHistoryButton extends ConsumerWidget {
  const CopiedMealHistoryButton({super.key, required this.source});

  final CopiedMealType source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
      icon: const Icon(Icons.show_chart_rounded, size: 18),
      label: Text(context.lang.copiedMealViewStatistics),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final previewMealId = await ref.read(
          copiedMealPreviewTargetProvider(source).future,
        );
        if (!context.mounted) return;
        if (previewMealId == null) {
          messenger.showSnackBar(
            SnackBar(content: Text(context.lang.copiedMealNoPreview)),
          );
          return;
        }
        await Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute(builder: (_) => MealPage(mealId: previewMealId)),
        );
      },
    );
  }
}
