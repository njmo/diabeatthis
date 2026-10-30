import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/ingredient_provider.dart';
import 'ingredient_form.dart';

Future<void> showCreateIngredientSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final previous = ref.read(ingredientDraftProvider);
  ref.invalidate(ingredientDraftProvider);
  ref.invalidate(ingredientFormKeyProvider);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateIngredientSheet(),
    );
  } finally {
    if (context.mounted) {
      ref.read(ingredientDraftProvider.notifier).overrideDraft(previous);
      ref.invalidate(ingredientFormKeyProvider);
    }
  }
}

class CreateIngredientSheet extends HookConsumerWidget {
  const CreateIngredientSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saving = useState(false);
    return PopScope(
      canPop: !saving.value,
      child: KeyboardAwareBottomSheet(
        header: BottomSheetStepHeader(
          title: context.lang.addIngredientTitle,
          onBack: saving.value ? () {} : () => Navigator.of(context).pop(),
        ),
        body: const IngredientForm(),
        actions: FilledButton(
          onPressed: saving.value
              ? null
              : () async {
                  if (!(ref
                          .read(ingredientFormKeyProvider)
                          .currentState
                          ?.validate() ??
                      false)) {
                    return;
                  }
                  saving.value = true;
                  try {
                    await ref.read(
                      insertIngredientProvider(
                        ref.read(ingredientDraftProvider),
                      ).future,
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.lang.ingredientSaveFailed(error),
                          ),
                        ),
                      );
                    }
                  } finally {
                    if (context.mounted) saving.value = false;
                  }
                },
          child: Text(context.lang.ingredientSaveTooltip),
        ),
      ),
    );
  }
}
