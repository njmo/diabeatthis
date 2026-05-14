import 'package:drift/drift.dart';

import '../../../domain/model/treat.dart' as domain;
import '../../../drift/database_impl.dart' as drift;
import '../../config/data_source_config.dart';

extension TreatDriftMapper on domain.Treat {
  drift.TreatCompanion toCompanion(EventSource source) {
    return drift.TreatCompanion.insert(
      source: source.storageValue,
      createdAt: createdAt.millisecondsSinceEpoch,
      carbs: Value(carbs.toDouble()),
    );
  }
}

extension TreatDomainMapper on drift.TreatData {
  domain.Treat toDomain() {
    return domain.Treat(
      id: id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      carbs: carbs?.round() ?? 0,
    );
  }
}
