import 'package:drift/drift.dart';

import '../../../domain/model/extended_carb.dart' as domain;
import '../../../drift/database_impl.dart' as drift;
import '../../config/data_source_config.dart';

extension ExtendedCarbDriftMapper on domain.ExtendedCarb {
  drift.ExtendedCarbCompanion toCompanion(EventSource source) {
    return drift.ExtendedCarbCompanion.insert(
      source: source.storageValue,
      externalId: externalId != null
          ? Value(externalId!)
          : const Value.absent(),
      createdAt: Value(createdAt.millisecondsSinceEpoch),
      carbs: Value(carbs.toDouble()),
      durationMinutes: Value(Duration(milliseconds: duration).inMinutes),
    );
  }
}

extension ExtendedCarbDomainMapper on drift.ExtendedCarbData {
  domain.ExtendedCarb toDomain() {
    return domain.ExtendedCarb(
      externalId: externalId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      carbs: carbs?.round() ?? 0,
      duration: Duration(minutes: durationMinutes ?? 0).inMilliseconds,
    );
  }
}
