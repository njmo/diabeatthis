import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../data/models/quick_low_treatment_slot.dart';

part 'swap_quick_low_treatment_item_slots_use_case.g.dart';

@riverpod
SwapQuickLowTreatmentItemSlotsUseCase swapQuickLowTreatmentItemSlotsUseCase(
  Ref ref,
) {
  return SwapQuickLowTreatmentItemSlotsUseCase(ref: ref);
}

class SwapQuickLowTreatmentItemSlotsUseCase {
  const SwapQuickLowTreatmentItemSlotsUseCase({required this.ref});

  final Ref ref;

  Future<void> call({
    required QuickLowTreatmentSlot source,
    required QuickLowTreatmentSlot target,
  }) async {
    final sourceItem = source.item;
    if (sourceItem == null || source.slot == target.slot) {
      return;
    }

    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await db.quickLowTreatmentItemDao.updateQuickLowTreatmentItemSortOrder(
        id: sourceItem.id,
        sortOrder: target.slot,
      );

      final targetItem = target.item;
      if (targetItem != null) {
        await db.quickLowTreatmentItemDao.updateQuickLowTreatmentItemSortOrder(
          id: targetItem.id,
          sortOrder: source.slot,
        );
      }
    });
  }
}
