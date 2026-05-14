import 'package:drift/drift.dart';

import '../../../domain/model/manual_bolus.dart' as domain;
import '../../../drift/database_impl.dart' as drift;
import '../../config/data_source_config.dart';

extension ManualBolusDriftMapper on domain.ManualBolus {
  drift.ManualBolusCompanion toCompanion(EventSource source) {
    return drift.ManualBolusCompanion.insert(
      source: source.storageValue,
      externalId: externalId != null
          ? Value(externalId!)
          : const Value.absent(),
      createdAt: Value(createdAt.millisecondsSinceEpoch),
      insulin: Value(insulin),
    );
  }
}

extension ManualBolusDomainMapper on drift.ManualBolusData {
  domain.ManualBolus toDomain() {
    return domain.ManualBolus(
      externalId: externalId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      insulin: insulin ?? 0,
    );
  }
}
