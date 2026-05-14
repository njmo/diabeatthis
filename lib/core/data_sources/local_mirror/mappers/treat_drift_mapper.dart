import 'package:drift/drift.dart';

import '../../../domain/model/treat.dart' as domain;
import '../../../drift/database_impl.dart' as drift;
import '../../config/data_source_config.dart';

extension TreatDriftMapper on domain.Treat {
  drift.TreatCompanion toCompanion(EventSource source) {
    return drift.TreatCompanion.insert(
      source: source.storageValue,
      externalId: externalId != null
          ? Value(externalId!)
          : const Value.absent(),
      createdAt: Value(createdAt.millisecondsSinceEpoch),
      carbs: Value(carbs.toDouble()),
    );
  }
}

extension TreatDomainMapper on drift.TreatData {
  domain.Treat toDomain() {
    return domain.Treat(
      externalId: externalId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      carbs: carbs?.round() ?? 0,
    );
  }
}
