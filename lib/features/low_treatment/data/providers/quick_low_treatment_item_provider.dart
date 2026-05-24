import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../../core/drift/providers/database_provider.dart';

part 'quick_low_treatment_item_provider.g.dart';

@riverpod
Stream<List<QuickLowTreatmentItem>> quickLowTreatmentItems(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.quickLowTreatmentItemDao.watchQuickLowTreatmentItems();
}
