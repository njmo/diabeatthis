import '../../domain/models/meal_photo_clarification_required.dart';
import '../../domain/models/meal_photo_proposal.dart';
import '../../domain/models/meal_photo_proposal_stage.dart';
import '../../domain/models/meal_photo_review_item.dart';

enum MealPhotoStep { capture, mode, assignment, amounts, confirmation, saved }

class MealPhotoState {
  MealPhotoState({
    this.step = MealPhotoStep.capture,
    this.proposal,
    this.clarification,
    this.progress,
    this.mode = MealPhotoMode.reference,
    List<MealPhotoReviewItem> items = const [],
    this.loading = false,
    this.saving = false,
    this.error,
    this.savedMealId,
  }) : items = List.unmodifiable(items);
  final MealPhotoStep step;
  final MealPhotoProposal? proposal;
  final MealPhotoClarificationRequired? clarification;
  final MealPhotoProposalStage? progress;
  final MealPhotoMode mode;
  final List<MealPhotoReviewItem> items;
  final bool loading;
  final bool saving;
  final Object? error;
  final int? savedMealId;
  bool get allAssigned =>
      items.isNotEmpty && items.every((item) => item.assigned);
  bool get allReviewed =>
      allAssigned && items.every((item) => item.reviewed && item.validWeight);
}
