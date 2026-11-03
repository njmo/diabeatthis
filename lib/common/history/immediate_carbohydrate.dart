import '../../core/domain/model/extended_carb.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';

/// AAPS may include duration: 0 for ordinary carbs. Keep extended delivery separate.
Treat? immediateCarbohydrate(Treatment treatment) => switch (treatment) {
  Treat() => treatment,
  ExtendedCarb(duration: 0) => Treat(
    externalId: treatment.externalId,
    createdAt: treatment.createdAt,
    carbs: treatment.carbs,
    isValid: treatment.isValid,
  ),
  _ => null,
};
