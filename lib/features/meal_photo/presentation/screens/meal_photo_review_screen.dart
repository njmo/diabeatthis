import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/edit_name_dialog.dart';
import '../../../../common/widgets/form_action_bar.dart';
import '../../../../common/widgets/form_step_header.dart';
import '../../../../common/widgets/sheet_content_height_request.dart';
import '../../../../common/widgets/sheet_content_section_reporter.dart';
import '../../domain/models/meal_photo_candidate.dart';
import '../../domain/models/meal_photo_nutrition.dart';
import '../../domain/models/meal_photo_proposal.dart';
import '../../domain/models/meal_photo_review_item.dart';
import '../controllers/meal_photo_controller.dart';
import '../controllers/meal_photo_state.dart';
import '../widgets/meal_photo_amount_tile.dart';
import '../widgets/meal_photo_assignment_tile.dart';
import '../widgets/meal_photo_clarification_card.dart';
import '../widgets/meal_photo_confirmation_tile.dart';
import '../widgets/meal_photo_creation_preview_scope.dart';
import '../widgets/meal_photo_existing_reference_dialog.dart';
import '../widgets/meal_photo_generation_progress.dart';
import '../widgets/meal_photo_ingredient_review_list.dart';
import '../widgets/meal_photo_mode_selector.dart';
import '../widgets/meal_photo_reference_editor.dart';
import '../widgets/meal_photo_review_error.dart';
import '../widgets/meal_photo_review_totals.dart';

/// Capture and persistence are injected so widget tests never access devices or storage.
class MealPhotoReviewScreen extends HookWidget {
  const MealPhotoReviewScreen({
    super.key,
    required this.controller,
    required this.capture,
    required this.pickProduct,
    required this.onSaved,
    this.reviewOptions,
    this.pickProductForItem,
    this.findReferenceMatches,
    this.canConfirm = true,
    this.confirmLabel,
  });
  final MealPhotoController controller;
  final Widget capture;
  final Widget? reviewOptions;
  final bool canConfirm;
  final String? confirmLabel;
  final Future<MealPhotoCandidate?> Function(BuildContext context) pickProduct;
  final ValueChanged<int> onSaved;
  final Future<MealPhotoCandidate?> Function(BuildContext, MealPhotoReviewItem)?
  pickProductForItem;

  final Future<List<MealPhotoCandidate>> Function(String name)?
  findReferenceMatches;

  @override
  Widget build(BuildContext context) {
    useListenable(controller);
    final scroll = useScrollController();
    final state = controller.state;
    Future<void> editReference({MealPhotoReviewItem? item}) async {
      final revision = controller.revision;
      var name = item?.displayName ?? '';
      var confidence = item == null
          ? .25
          : item.referenceNutrition != null
          ? item.referenceNutritionConfidence
          : item.nutritionConfidence;
      final nutrition = await showDialog<MealPhotoNutrition>(
        context: context,
        builder: (_) => MealPhotoReferenceEditor(
          name: name,
          initialNutrition: item?.editableReferenceNutrition,
          initialConfidence: confidence,
          onConfidenceSaved: (value) => confidence = value,
          onNameSaved: item == null ? (value) => name = value : null,
        ),
      );
      if (nutrition == null ||
          !context.mounted ||
          controller.disposed ||
          controller.revision != revision) {
        return;
      }
      final List<MealPhotoCandidate> matches;
      try {
        matches =
            await findReferenceMatches?.call(name) ??
            const <MealPhotoCandidate>[];
      } catch (error) {
        if (context.mounted && !controller.disposed) {
          controller.reportReviewError(error);
        }
        return;
      }
      if (!context.mounted ||
          controller.disposed ||
          controller.revision != revision) {
        return;
      }
      if (matches.isNotEmpty) {
        final choice = await showDialog<Object>(
          context: context,
          builder: (_) => MealPhotoExistingReferenceDialog(matches: matches),
        );
        if (!context.mounted ||
            controller.disposed ||
            controller.revision != revision ||
            choice == null) {
          return;
        }
        if (choice is MealPhotoCandidate) {
          if (item == null) {
            controller.addIngredient(product: choice);
          } else {
            controller.assignProduct(item.proposal.id, choice);
          }
          return;
        }
      }
      if (item == null) {
        controller.addIngredient(
          name: name,
          nutrition: nutrition,
          confidence: confidence,
        );
      } else {
        controller.setManualReference(
          item.proposal.id,
          nutrition,
          confidence: confidence,
        );
      }
    }

    Future<void> acceptReference(MealPhotoReviewItem item) async {
      if (findReferenceMatches == null) {
        controller.acceptReference(item.proposal.id);
        return;
      }
      final revision = controller.revision;
      try {
        final matches = await findReferenceMatches!(item.displayName);
        if (!context.mounted ||
            controller.disposed ||
            controller.revision != revision) {
          return;
        }
        if (matches.isNotEmpty) {
          final choice = await showDialog<Object>(
            context: context,
            builder: (_) => MealPhotoExistingReferenceDialog(matches: matches),
          );
          if (!context.mounted ||
              controller.disposed ||
              controller.revision != revision ||
              choice == null) {
            return;
          }
          if (choice is MealPhotoCandidate) {
            controller.assignProduct(item.proposal.id, choice);
            return;
          }
        }
        controller.acceptReference(item.proposal.id);
      } catch (error) {
        if (context.mounted && !controller.disposed) {
          controller.reportReviewError(error);
        }
      }
    }

    final hasFooter =
        state.step != MealPhotoStep.capture &&
        state.step != MealPhotoStep.mode &&
        state.step != MealPhotoStep.saved;
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (scroll.hasClients) scroll.jumpTo(0);
        if (!hasFooter) {
          const SheetContentHeightRequest(
            SheetContentSection.footer,
            0,
          ).dispatch(context);
        }
      });
      return null;
    }, [state.step]);
    final busy = state.loading || state.saving;
    final canContinue = state.allReviewed;
    final canGoBack =
        state.step == MealPhotoStep.mode ||
        state.step == MealPhotoStep.assignment ||
        state.step == MealPhotoStep.amounts ||
        state.step == MealPhotoStep.confirmation;
    void back() {
      if (state.saving) return;
      FocusScope.of(context).unfocus();
      if (state.loading) {
        controller.cancel();
        Navigator.of(context).maybePop();
        return;
      }
      if (canGoBack) {
        controller.back();
      } else {
        Navigator.of(context).maybePop();
      }
    }

    return PopScope(
      canPop: !state.saving && !canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy && canGoBack) controller.back();
      },
      child: MealPhotoCreationPreviewScope(
        check: controller.checkIngredientCreation,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: state.saving ? null : back),
            title: Text(context.lang.mealPhotoTitle),
          ),
          body: SafeArea(
            bottom: !hasFooter,
            child: Column(
              children: [
                SheetContentSectionReporter(
                  section: SheetContentSection.header,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        FormStepHeader(
                          labelsBelowMarkers: true,
                          currentStep: switch (state.step) {
                            MealPhotoStep.capture => 0,
                            MealPhotoStep.mode || MealPhotoStep.assignment => 1,
                            MealPhotoStep.amounts => 1,
                            _ => 2,
                          },
                          labels: [
                            context.lang.mealPhotoStepContext,
                            context.lang.mealPhotoIngredientsAndPortions,
                            context.lang.mealFlowReview,
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scroll,
                    child: SheetContentSectionReporter(
                      section: SheetContentSection.body,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state.step != MealPhotoStep.confirmation)
                              Text(
                                (state.step == MealPhotoStep.amounts ||
                                        state.step == MealPhotoStep.assignment)
                                    ? context.lang.mealPhotoPortionReviewHint
                                    : context.lang.mealPhotoEstimateNotice,
                              ),
                            const SizedBox(height: 16),
                            if (state.loading)
                              MealPhotoGenerationProgress(
                                stage: state.progress,
                              ),
                            if (state.clarification != null)
                              MealPhotoClarificationCard(
                                clarification: state.clarification!,
                              ),
                            if (state.error != null)
                              MealPhotoReviewError(error: state.error!),
                            if (state.proposal != null &&
                                state.step == MealPhotoStep.confirmation)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      controller.mealName,
                                      style:
                                          state.step == MealPhotoStep.amounts ||
                                              state.step ==
                                                  MealPhotoStep.confirmation
                                          ? Theme.of(
                                              context,
                                            ).textTheme.titleMedium
                                          : Theme.of(
                                              context,
                                            ).textTheme.headlineSmall,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: context.lang.mealPhotoEditMealName,
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: state.loading || state.saving
                                        ? null
                                        : () async {
                                            final revision =
                                                controller.revision;
                                            final name = await showDialog<String>(
                                              context: context,
                                              builder: (_) => EditNameDialog(
                                                initialName:
                                                    controller.mealName,
                                                title: context
                                                    .lang
                                                    .mealPhotoEditMealName,
                                                label: context
                                                    .lang
                                                    .mealNameTypeLabel,
                                                requiredMessage: context
                                                    .lang
                                                    .mealPhotoMealNameRequired,
                                              ),
                                            );
                                            if (name != null &&
                                                context.mounted &&
                                                !controller.disposed &&
                                                controller.revision ==
                                                    revision) {
                                              controller.renameMeal(name);
                                            }
                                          },
                                  ),
                                ],
                              ),
                            Offstage(
                              offstage:
                                  state.step != MealPhotoStep.capture ||
                                  state.loading,
                              child: capture,
                            ),
                            if (state.step == MealPhotoStep.mode)
                              MealPhotoModeSelector(
                                proposal: state.proposal!,
                                onUseWholePlate:
                                    controller.acceptWholePlateProposal,
                                onEditReference: () async {
                                  final revision = controller.revision;
                                  final proposal = controller.state.proposal!;
                                  final item =
                                      state.mode == MealPhotoMode.reference &&
                                          state.items.length == 1 &&
                                          identical(
                                            state.items.single.proposal,
                                            proposal.reference,
                                          )
                                      ? state.items.single
                                      : MealPhotoReviewItem.fromProposal(
                                          proposal.reference,
                                        );
                                  var referenceConfidence =
                                      item.referenceNutritionConfidence;
                                  final nutrition =
                                      await showDialog<MealPhotoNutrition>(
                                        context: context,
                                        builder: (_) =>
                                            MealPhotoReferenceEditor(
                                              name: item.displayName,
                                              initialNutrition: item
                                                  .editableReferenceNutrition,
                                              initialConfidence:
                                                  referenceConfidence,
                                              onConfidenceSaved: (value) =>
                                                  referenceConfidence = value,
                                            ),
                                      );
                                  if (nutrition != null &&
                                      context.mounted &&
                                      !controller.disposed &&
                                      controller.revision == revision &&
                                      controller.state.step ==
                                          MealPhotoStep.mode) {
                                    controller.editWholePlateReference(
                                      nutrition,
                                      confidence: referenceConfidence,
                                    );
                                  }
                                },
                                referenceConfidence:
                                    state.mode == MealPhotoMode.reference &&
                                        state.items.length == 1
                                    ? state
                                          .items
                                          .single
                                          .referenceNutritionConfidence
                                    : null,
                                referenceNutrition:
                                    state.mode == MealPhotoMode.reference &&
                                        state.items.length == 1
                                    ? state.items.single.referenceNutrition
                                    : null,
                                onDivide: () =>
                                    controller.divideIntoIngredients(
                                      languageCode: Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                    ),
                              ),
                            if ((state.step == MealPhotoStep.assignment ||
                                    (state.step == MealPhotoStep.amounts &&
                                        state.mode ==
                                            MealPhotoMode.itemized)) &&
                                !busy)
                              MealPhotoIngredientReviewList(
                                key: ValueKey(state.proposal),
                                items: state.items,
                                builder: (item, onConfirmed) => MealPhotoAssignmentTile(
                                  key: ValueKey(item.proposal.id),
                                  item: item,
                                  onNutritionConfidenceChanged: (confidence) =>
                                      controller.setAmount(
                                        item.proposal.id,
                                        grams: item.weightGrams ?? 0,
                                        quantityConfidence:
                                            item.quantityConfidence,
                                        nutritionConfidence: confidence,
                                        reviewed: false,
                                      ),
                                  onAmountChanged: (grams) =>
                                      controller.setAmount(
                                        item.proposal.id,
                                        grams: grams,
                                        quantityConfidence:
                                            item.quantityConfidence,
                                        nutritionConfidence:
                                            item.nutritionConfidence,
                                        reviewed: false,
                                      ),
                                  onConfirm: () {
                                    controller.setAmount(
                                      item.proposal.id,
                                      grams: item.weightGrams!,
                                      quantityConfidence:
                                          item.quantityConfidence,
                                      nutritionConfidence:
                                          item.nutritionConfidence,
                                      reviewed: true,
                                    );
                                    onConfirmed();
                                  },
                                  allowProduct:
                                      state.mode == MealPhotoMode.itemized,
                                  onRemove: state.mode == MealPhotoMode.itemized
                                      ? () {
                                          final proposal =
                                              controller.state.proposal;
                                          final index = controller.state.items
                                              .indexOf(item);
                                          controller.removeIngredient(
                                            item.proposal.id,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                context
                                                    .lang
                                                    .mealPhotoIngredientRemoved,
                                              ),
                                              action: SnackBarAction(
                                                label: context
                                                    .lang
                                                    .mealPhotoUndoRemoval,
                                                onPressed: () {
                                                  if (!controller.disposed &&
                                                      identical(
                                                        controller
                                                            .state
                                                            .proposal,
                                                        proposal,
                                                      ) &&
                                                      !controller
                                                          .state
                                                          .loading &&
                                                      !controller
                                                          .state
                                                          .saving &&
                                                      (controller.state.step ==
                                                              MealPhotoStep
                                                                  .assignment ||
                                                          controller
                                                                  .state
                                                                  .step ==
                                                              MealPhotoStep
                                                                  .amounts)) {
                                                    controller
                                                        .restoreIngredient(
                                                          item,
                                                          index,
                                                        );
                                                  }
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  onAssign: () async {
                                    final proposal = controller.state.proposal;
                                    final revision = controller.revision;
                                    try {
                                      final product =
                                          await (pickProductForItem != null
                                              ? pickProductForItem!(
                                                  context,
                                                  item,
                                                )
                                              : pickProduct(context));
                                      if (product != null &&
                                          context.mounted &&
                                          identical(
                                            proposal,
                                            controller.state.proposal,
                                          ) &&
                                          revision == controller.revision &&
                                          (controller.state.step ==
                                                  MealPhotoStep.assignment ||
                                              controller.state.step ==
                                                  MealPhotoStep.amounts)) {
                                        controller.assignProduct(
                                          item.proposal.id,
                                          product,
                                        );
                                      }
                                    } catch (error) {
                                      if (context.mounted &&
                                          identical(
                                            proposal,
                                            controller.state.proposal,
                                          ) &&
                                          revision == controller.revision) {
                                        controller.reportReviewError(error);
                                      }
                                    }
                                  },
                                  onReference: () => acceptReference(item),
                                  onCreateReference: () =>
                                      editReference(item: item),
                                ),
                              ),
                            if (!busy &&
                                state.mode == MealPhotoMode.itemized &&
                                (state.step == MealPhotoStep.assignment ||
                                    state.step == MealPhotoStep.amounts))
                              PopupMenuButton<String>(
                                tooltip: context.lang.mealPhotoAddIngredient,
                                onSelected: (choice) async {
                                  try {
                                    if (choice == 'reference') {
                                      await editReference();
                                      return;
                                    }
                                    final revision = controller.revision;
                                    final product = await pickProduct(context);
                                    if (product != null &&
                                        context.mounted &&
                                        !controller.disposed &&
                                        controller.revision == revision) {
                                      controller.addIngredient(
                                        product: product,
                                      );
                                    }
                                  } catch (error) {
                                    if (context.mounted &&
                                        !controller.disposed) {
                                      controller.reportReviewError(error);
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'product',
                                    child: Text(context.lang.mealPhotoAssign),
                                  ),
                                  PopupMenuItem(
                                    value: 'reference',
                                    child: Text(
                                      context.lang.mealPhotoAddReference,
                                    ),
                                  ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add),
                                      const SizedBox(width: 8),
                                      Text(context.lang.mealPhotoAddIngredient),
                                    ],
                                  ),
                                ),
                              ),
                            if (state.step == MealPhotoStep.amounts) ...[
                              const SizedBox(height: 12),
                              Text(
                                context.lang.mealPhotoPortionReviewProgress(
                                  state.items
                                      .where((item) => item.reviewed)
                                      .length,
                                  state.items.length,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (state.step == MealPhotoStep.amounts &&
                                state.mode == MealPhotoMode.reference &&
                                state.items.length == 1)
                              ...state.items.map(
                                (item) => MealPhotoAmountTile(
                                  key: ValueKey(item.proposal.id),
                                  item: item,
                                  onChanged:
                                      (grams, quantity, nutrition, reviewed) =>
                                          controller.setAmount(
                                            item.proposal.id,
                                            grams: grams,
                                            quantityConfidence: quantity,
                                            nutritionConfidence: nutrition,
                                            reviewed: reviewed,
                                          ),
                                ),
                              ),
                            if (state.step == MealPhotoStep.confirmation)
                              MealPhotoReviewTotals(items: state.items),
                            if (state.step == MealPhotoStep.confirmation &&
                                reviewOptions != null)
                              reviewOptions!,
                            if (state.step == MealPhotoStep.confirmation)
                              ...state.items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: MealPhotoConfirmationTile(item: item),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: !hasFooter
              ? null
              : SheetContentSectionReporter(
                  section: SheetContentSection.footer,
                  child: FormActionBar(
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: busy ? null : controller.back,
                          child: Text(context.lang.mealPhotoBack),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                busy ||
                                    !canContinue ||
                                    (state.step == MealPhotoStep.confirmation &&
                                        !canConfirm)
                                ? null
                                : () async {
                                    FocusScope.of(context).unfocus();
                                    if (state.step !=
                                        MealPhotoStep.confirmation) {
                                      try {
                                        controller.next();
                                      } catch (error) {
                                        controller.reportReviewError(error);
                                      }
                                      return;
                                    }
                                    try {
                                      final id = await controller.save(
                                        confirmed: true,
                                      );
                                      if (context.mounted) onSaved(id);
                                    } catch (_) {
                                      /* Error stays in controller state for retry. */
                                    }
                                  },
                            child: state.saving
                                ? const CircularProgressIndicator()
                                : Text(
                                    state.step == MealPhotoStep.confirmation
                                        ? confirmLabel ??
                                              context.lang.mealPhotoConfirm
                                        : context.lang.mealPhotoNext,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
