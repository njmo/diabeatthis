import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../../common/widgets/forms.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../ingredients/data/models/ingredient_scan_result.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../ingredients/presentation/widgets/ingredient_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_photo_scan.dart';
import '../../../ingredients/presentation/widgets/ingredient_portion_amount_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_scan_review_dialog.dart';
import '../../../ingredients/presentation/widgets/ingredient_search.dart';
import '../../../meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../../meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../../portions/presentation/widgets/portion_form.dart';
import '../../../portions/presentation/widgets/portion_search.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import 'amount_form.dart';
import 'summary.dart';

Future<MealIngredientsDraft?> showAddMealIngredientSheet({
  required BuildContext context,
  required WidgetRef ref,
  MealIngredientsDraft? initialDraft,
}) {
  ref.invalidate(addMealIngredientStageProvider);
  ref.invalidate(mealIngredientsDraftProvider);
  ref.invalidate(mealIngredientAmountDraftProvider);
  ref.invalidate(mealIngredientConfidenceDraftProvider);

  if (initialDraft != null) {
    // Keep the existing draft subscription while the editor moves between stages.
    ref.watch(mealIngredientsDraftProvider.notifier);
    ref
        .watch(addMealIngredientStageProvider.notifier)
        .editIngredient(initialDraft);
  }

  return showModalBottomSheet<MealIngredientsDraft>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (_) => const AddMealIngredient(),
  );
}

class AddMealIngredient extends ConsumerWidget {
  const AddMealIngredient({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(portionFilterProvider);
    ref.watch(ingredientDraftProvider);
    final addingStage = ref.watch(addMealIngredientStageProvider);
    final photoScanState = ref.watch(ingredientPhotoScanControllerProvider);
    final photoScanInput = ref.watch(
      ingredientPhotoScanCaptureControllerProvider,
    );
    final isScanningIngredient =
        addingStage == AddMealIngredientStage.ingredientPhotoScan &&
        photoScanState.isLoading;
    final isIngredientPhotoScanStage =
        addingStage == AddMealIngredientStage.ingredientPhotoScan;
    final canScanIngredientPhotos =
        !isIngredientPhotoScanStage || photoScanInput.hasRequiredPhotos;
    final addingStateNotifier = ref.read(
      addMealIngredientStageProvider.notifier,
    );
    if (addingStage == AddMealIngredientStage.dismiss) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }

    return KeyboardAwareBottomSheet(
      header: switch (addingStage) {
        AddMealIngredientStage.dismiss => const SizedBox.shrink(),
        AddMealIngredientStage.ingredientSearch => BottomSheetStepHeader(
          title: context.lang.addIngredientSearchTitle,
          onBack: () => Navigator.of(context).pop(),
        ),
        AddMealIngredientStage.ingredientPhotoScan => BottomSheetStepHeader(
          title: context.lang.addIngredientFromPhotosTitle,
          onBack: addingStateNotifier.back,
        ),
        AddMealIngredientStage.ingredientForm => BottomSheetStepHeader(
          title: context.lang.addIngredientTitle,
          onBack: addingStateNotifier.back,
          actions: [
            IconButton(
              tooltip: context.lang.addIngredientSearchTitle,
              onPressed: addingStateNotifier.toOppositeStage,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        AddMealIngredientStage.portionAddNewSearch => BottomSheetStepHeader(
          title: context.lang.addIngredientPickPortionTitle,
          onBack: addingStateNotifier.back,
          actions: [
            IconButton(
              tooltip: context.lang.addIngredientAddPortionTooltip,
              onPressed: addingStateNotifier.toOppositeStage,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        AddMealIngredientStage.definedPortionsSearch => BottomSheetStepHeader(
          title: context.lang.addIngredientSearchExistingPortionTitle,
          onBack: addingStateNotifier.back,
          actions: [
            IconButton(
              tooltip: context.lang.addIngredientAddPortionTooltip,
              onPressed: addingStateNotifier.toOppositeStage,
              icon: const Icon(Icons.add_box_outlined),
            ),
          ],
        ),
        AddMealIngredientStage.amountForm => BottomSheetStepHeader(
          title: context.lang.addIngredientAmountTitle,
          onBack: addingStateNotifier.back,
        ),
        AddMealIngredientStage.summary => BottomSheetStepHeader(
          title: context.lang.addIngredientSummaryTitle,
          onBack: addingStateNotifier.back,
        ),
        AddMealIngredientStage.portionSpecifyAmount => BottomSheetStepHeader(
          title: context.lang.addIngredientPortionWeightTitle,
          onBack: addingStateNotifier.back,
        ),
        AddMealIngredientStage.portionAddNewForm => BottomSheetStepHeader(
          title: context.lang.addIngredientNewPortionTitle,
          onBack: addingStateNotifier.back,
          actions: [
            IconButton(
              tooltip: context.lang.addIngredientSearchPortionTooltip,
              onPressed: addingStateNotifier.toOppositeStage,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
      },
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: switch (addingStage) {
          AddMealIngredientStage.dismiss => const SizedBox.shrink(),
          AddMealIngredientStage.ingredientSearch => IngredientSearch(),
          AddMealIngredientStage.ingredientPhotoScan => IngredientPhotoScan(),
          AddMealIngredientStage.ingredientForm => const SingleChildScrollView(
            child: IngredientForm(),
          ),
          AddMealIngredientStage.portionAddNewSearch => PortionSearch(),
          AddMealIngredientStage.definedPortionsSearch => PortionSearch(),
          AddMealIngredientStage.amountForm => AmountForm(),
          AddMealIngredientStage.summary => AddIngredientSummary(),
          AddMealIngredientStage.portionSpecifyAmount =>
            IngredientPortionAmountForm(
              amount: ref.watch(
                mealIngredientsDraftProvider.select(
                  (draft) => draft.ingredientPortion.amount,
                ),
              ),
              onAmountChanged: ref
                  .read(mealIngredientsDraftProvider.notifier)
                  .setIngredientPortionAmount,
            ),
          AddMealIngredientStage.portionAddNewForm => PortionForm(),
        },
      ),
      actions: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isScanningIngredient || !canScanIngredientPhotos
                  ? null
                  : () async {
                      if (addingStage == AddMealIngredientStage.summary) {
                        Navigator.of(
                          context,
                        ).pop(ref.read(mealIngredientsDraftProvider));
                      } else if (addingStage ==
                          AddMealIngredientStage.ingredientPhotoScan) {
                        await addingStateNotifier.nextStage();
                        if (!context.mounted) {
                          return;
                        }
                        final scanResult = ref
                            .read(ingredientPhotoScanControllerProvider)
                            .when(
                              data: (value) => value,
                              error: (_, _) => null,
                              loading: () => null,
                            );
                        if (scanResult?.status ==
                            IngredientScanStatus.needsReview) {
                          final shouldContinue =
                              await showIngredientScanReviewDialog(
                                context: context,
                                result: scanResult!,
                              );
                          if (shouldContinue == true) {
                            addingStateNotifier
                                .continueWithIngredientScanReview();
                          }
                        }
                      } else {
                        final formKey = _formKeyForStage(ref, addingStage);
                        if (validateForm(formKey)) {
                          await addingStateNotifier.nextStage();
                        }
                      }
                    },
              child: (addingStage == AddMealIngredientStage.summary)
                  ? Text(context.lang.mealSummaryExtraAdd)
                  : Text(
                      isScanningIngredient
                          ? context.lang.addIngredientReadingData
                          : addingStage ==
                                AddMealIngredientStage.ingredientPhotoScan
                          ? photoScanInput.hasRequiredPhotos
                                ? context.lang.addIngredientReadData
                                : context.lang.addIngredientAddPhotos
                          : context.lang.addIngredientNext,
                    ),
            ),
          ),
          addingStage != AddMealIngredientStage.definedPortionsSearch &&
                  addingStage != AddMealIngredientStage.portionAddNewSearch
              ? SizedBox.shrink()
              : Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      addingStateNotifier.setOverride();
                    },
                    child: Text(context.lang.addIngredientAddInGrams),
                  ),
                ),
          addingStage != AddMealIngredientStage.summary
              ? SizedBox.shrink()
              : Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            context.lang.addIngredientDiscardChangesTitle,
                          ),
                          content: Text(
                            context.lang.addIngredientDiscardChangesMessage,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                              child: Text(context.lang.commonYes),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                              child: Text(context.lang.commonNo),
                            ),
                          ],
                        ),
                      );
                      if (result == true) {
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    child: Text(context.lang.addIngredientDiscard),
                  ),
                ),
        ],
      ),
    );
  }
}

GlobalKey<FormState> _formKeyForStage(
  WidgetRef ref,
  AddMealIngredientStage stage,
) {
  return switch (stage) {
    AddMealIngredientStage.ingredientSearch => ref.read(
      ingredientSearchFormKeyProvider,
    ),
    AddMealIngredientStage.ingredientForm => ref.read(
      ingredientFormKeyProvider,
    ),
    _ => ref.read(mealIngredientFormKeyProvider),
  };
}
