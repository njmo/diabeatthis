import 'meal_photo_proposal.dart';
import 'meal_photo_review_item.dart';

class AcceptedMealPhotoReview {
  AcceptedMealPhotoReview({
    required this.name,
    required this.mode,
    required List<MealPhotoReviewItem> items,
    required this.proposalResponse,
    required this.sourceProposal,
    Set<String> excludedItemIds = const {},
  }) : items = List.unmodifiable(items),
       excludedItemIds = Set.unmodifiable(excludedItemIds);
  final String name;
  final MealPhotoMode mode;
  final List<MealPhotoReviewItem> items;
  final String proposalResponse;
  final MealPhotoProposal sourceProposal;
  final Set<String> excludedItemIds;
}
