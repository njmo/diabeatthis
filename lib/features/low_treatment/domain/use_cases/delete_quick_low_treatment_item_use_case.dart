import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../../core/drift/providers/database_provider.dart';

part 'delete_quick_low_treatment_item_use_case.g.dart';

@riverpod
DeleteQuickLowTreatmentItemUseCase deleteQuickLowTreatmentItemUseCase(Ref ref) {
  return DeleteQuickLowTreatmentItemUseCase(ref: ref);
}

class DeleteQuickLowTreatmentItemUseCase {
  const DeleteQuickLowTreatmentItemUseCase({required this.ref});

  final Ref ref;

  Future<void> call(QuickLowTreatmentItem item) async {
    final db = ref.read(databaseProvider);
    await db.quickLowTreatmentItemDao.deleteQuickLowTreatmentItem(item.id);
  }
}
