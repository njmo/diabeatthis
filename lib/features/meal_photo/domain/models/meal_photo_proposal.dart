import 'meal_photo_item.dart';

enum MealPhotoMode { itemized, reference }

class MealPhotoProposal {
  MealPhotoProposal({
    required this.name,
    required List<MealPhotoItem> itemized,
    required this.reference,
    required this.rawResponse,
  }) : itemized = List.unmodifiable(itemized);
  final String name;
  final List<MealPhotoItem> itemized;
  final MealPhotoItem reference;
  final String rawResponse;
  List<MealPhotoItem> itemsFor(MealPhotoMode mode) =>
      mode == MealPhotoMode.itemized ? itemized : [reference];
}
