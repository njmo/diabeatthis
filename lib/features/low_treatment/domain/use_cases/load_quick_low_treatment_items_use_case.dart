import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../../core/drift/providers/database_provider.dart';

part 'load_quick_low_treatment_items_use_case.g.dart';

@riverpod
LoadQuickLowTreatmentItemsUseCase loadQuickLowTreatmentItemsUseCase(Ref ref) {
  return LoadQuickLowTreatmentItemsUseCase(ref: ref);
}

class LoadQuickLowTreatmentItemsUseCase {
  const LoadQuickLowTreatmentItemsUseCase({required this.ref});

  final Ref ref;

  Future<List<QuickLowTreatmentItem>> call() {
    final db = ref.read(databaseProvider);
    return db.quickLowTreatmentItemDao.getQuickLowTreatmentItems();
  }
}
