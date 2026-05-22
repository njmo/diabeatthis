import '../../domain/model/low_treatment_context.dart' as domain;
import '../database_impl.dart';

extension LowTreatmentContextDataToDomain on LowTreatmentContextData {
  domain.LowTreatmentContext toDomain() {
    return domain.LowTreatmentContext(
      mealId: mealId,
      relatedMealId: relatedMealId,
      source: domain.LowTreatmentContextSource.fromStorage(source),
      suggestedCarbs: suggestedCarbs,
      suggestedWithinMinutes: suggestedWithinMinutes,
      suggestionAt: _date(suggestionAt),
      deviceStatusDate: _date(deviceStatusDate),
      reason: domain.LowTreatmentReason.fromStorage(reason),
      isSynced: isSynced,
      createdAt: _date(createdAt),
      updatedAt: _date(updatedAt),
    );
  }

  DateTime? _date(int? millisecondsSinceEpoch) {
    if (millisecondsSinceEpoch == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  }
}
