import 'package:drift/drift.dart';

import '../../../domain/model/correction_bolus.dart' as domain;
import '../../../drift/database_impl.dart' as drift;
import '../../config/data_source_config.dart';

extension CorrectionBolusDriftMapper on domain.CorrectionBolus {
  drift.CorrectionBolusCompanion toCompanion(TreatmentsSource source) {
    return drift.CorrectionBolusCompanion.insert(
      source: source.storageValue,
      externalId: externalId != null
          ? Value(externalId!)
          : const Value.absent(),
      createdAt: Value(createdAt.millisecondsSinceEpoch),
      insulin: Value(insulin),
    );
  }
}

extension CorrectionBolusDomainMapper on drift.CorrectionBolusData {
  domain.CorrectionBolus toDomain() {
    return domain.CorrectionBolus(
      externalId: externalId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      insulin: insulin ?? 0,
    );
  }
}
