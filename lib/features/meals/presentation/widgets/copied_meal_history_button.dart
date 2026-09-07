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
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.history, size: 18),
      label: Text(context.lang.copiedMealHistoryDetails),
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
