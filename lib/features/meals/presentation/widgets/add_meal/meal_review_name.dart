import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/review_section_header.dart';
import '../../../data/providers/meal_draft_provider.dart';
import '../../../data/providers/meal_name_ingredients_provider.dart';
import 'meal_name_field.dart';
import 'meal_name_formatter.dart';

class MealReviewName extends HookConsumerWidget {
  const MealReviewName({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editing = useState(false);
    final names = ref.watch(mealNameIngredientsProvider);
    final draft = ref.watch(mealDraftProvider);
    final joined = names.asData?.value.join(', ');
    final generated = joined == null || joined.isEmpty
        ? null
        : formatAutomaticMealName(
            context.lang,
            names.asData!.value,
            draft.category,
          );
    useEffect(() {
      if (generated != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ref
                .read(mealDraftProvider.notifier)
                .applyGeneratedName(
                  generated.length > 120
                      ? generated.substring(0, 120)
                      : generated,
                );
          }
        });
      }
      return null;
    }, [generated]);
    if (editing.value) {
      return MealNameField(
        onSaved: ref.read(mealDraftProvider.notifier).setName,
      );
    }
    return ReviewSectionHeader(
      title: draft.name.isNotEmpty
          ? draft.name
          : generated ?? context.lang.commonLoading,
      actionLabel: context.lang.mealEditName,
      onChange: () => editing.value = true,
    );
  }
}
