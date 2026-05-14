import 'package:drift/drift.dart';

import '../../../domain/model/glucose.dart' as domain;
import '../../../drift/database_impl.dart';

extension GlucoseDriftMapper on domain.Glucose {
  GlucoseReadingCompanion toCompanion() {
    return GlucoseReadingCompanion.insert(
      source: source.storageValue,
      externalId: externalId != null
          ? Value(externalId!)
          : const Value.absent(),
      createdAt: Value(date.millisecondsSinceEpoch),
      sgv: sgv,
      direction: Value(direction),
    );
  }
}

extension GlucoseDomainMapper on GlucoseReadingData {
  domain.Glucose toDomain() {
    return domain.Glucose(
      externalId: externalId,
      source: domain.GlucoseSource.fromStorage(source),
      date: DateTime.fromMillisecondsSinceEpoch(createdAt),
      sgv: sgv,
      direction: direction ?? '',
    );
  }
}
