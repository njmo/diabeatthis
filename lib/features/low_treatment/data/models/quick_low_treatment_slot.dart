import '../../../../core/domain/model/quick_low_treatment_item.dart';

class QuickLowTreatmentSlot {
  const QuickLowTreatmentSlot({required this.slot, this.item});

  final int slot;
  final QuickLowTreatmentItem? item;

  QuickLowTreatmentSlot withItem(QuickLowTreatmentItem? item) {
    return QuickLowTreatmentSlot(slot: slot, item: item);
  }
}

List<QuickLowTreatmentSlot> buildQuickLowTreatmentSlots(
  List<QuickLowTreatmentItem> items,
) {
  return [
    for (var index = 0; index < maxQuickLowTreatmentItems; index++)
      QuickLowTreatmentSlot(
        slot: index + 1,
        item: quickLowTreatmentItemForSlot(items, index + 1),
      ),
  ];
}

QuickLowTreatmentItem? quickLowTreatmentItemForSlot(
  List<QuickLowTreatmentItem> items,
  int slot,
) {
  final matchingItems = items.where((item) => item.sortOrder == slot);
  if (matchingItems.isEmpty) {
    return null;
  }
  return matchingItems.first;
}
