import 'package:drift/drift.dart';

import '../../../domain/model/correction_bolus.dart' as domain;
import '../../../drift/database_impl.dart' as drift;
import '../../config/data_source_config.dart';

extension CorrectionBolusDriftMapper on domain.CorrectionBolus {
  drift.CorrectionBolusCompanion toCompanion(EventSource source) {
    return drift.CorrectionBolusCompanion.insert(
      source: source.storageValue,
      createdAt: createdAt.millisecondsSinceEpoch,
      insulin: Value(insulin),
    );
  }
}

extension CorrectionBolusDomainMapper on drift.CorrectionBolusData {
  domain.CorrectionBolus toDomain() {
    return domain.CorrectionBolus(
      id: id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      insulin: insulin ?? 0,
    );
  }
}
