import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../../common/widgets/responsive_bottom_sheet.dart';
import '../../../meals/data/providers/ingredient_flow_form_providers.dart';
import '../../data/drafts/ingredient_draft.dart';
import '../../data/providers/ingredient_provider.dart';
import '../controllers/barcode_ingredient_review_controller.dart';
import '../controllers/seeded_ingredient_draft_notifier.dart';
import 'ingredient_form.dart';

Future<IngredientDraft?> showBarcodeIngredientReviewSheet(
  BuildContext context, {
  required IngredientDraft draft,
  required bool needsReview,
}) => showResponsiveBottomSheet<IngredientDraft>(
  context: context,
  isScrollControlled: true,
  builder: (_) => ProviderScope(
    overrides: [
      ingredientDraftProvider.overrideWith(
        () => SeededIngredientDraftNotifier(draft),
      ),
      ingredientFormKeyProvider.overrideWith((_) => GlobalKey<FormState>()),
      barcodeIngredientReviewControllerProvider.overrideWith(
        BarcodeIngredientReviewController.new,
      ),
    ],
    child: BarcodeIngredientReviewSheet(needsReview: needsReview),
  ),
);

class BarcodeIngredientReviewSheet extends HookConsumerWidget {
  const BarcodeIngredientReviewSheet({super.key, required this.needsReview});
  final bool needsReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmed = useState(!needsReview);
    final state = ref.watch(barcodeIngredientReviewControllerProvider);
    final busy = state.isLoading;

    return KeyboardAwareBottomSheet(
      header: BottomSheetStepHeader(
        title: context.lang.barcodeReviewTitle,
        onBack: () => Navigator.pop(context),
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (needsReview) Text(context.lang.barcodeReviewIncomplete),
            if (state.hasError)
              Text(
                context.lang.barcodeReviewSelectionFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            IngredientForm(sectioned: true, showReferenceToggle: false),
            if (needsReview)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed.value,
                title: Text(context.lang.barcodeReviewConfirmFacts),
                onChanged: (value) => confirmed.value = value ?? false,
              ),
          ],
        ),
      ),
      actions: Row(
        children: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(context.lang.barcodeReviewReject),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: busy || !confirmed.value
                  ? null
                  : () {
                      if (!(ref
                              .read(ingredientFormKeyProvider)
                              .currentState
                              ?.validate() ??
                          false)) {
                        return;
                      }
                      final draft = ref
                          .read(
                            barcodeIngredientReviewControllerProvider.notifier,
                          )
                          .confirmManual(ref.read(ingredientDraftProvider));
                      if (draft != null) Navigator.pop(context, draft);
                    },
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.lang.barcodeReviewUseProduct),
            ),
          ),
        ],
      ),
    );
  }
}
