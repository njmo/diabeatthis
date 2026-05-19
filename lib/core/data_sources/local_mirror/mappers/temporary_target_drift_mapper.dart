import 'package:drift/drift.dart';

import '../../../domain/model/temporary_target.dart' as domain;
import '../../../drift/database_impl.dart' as drift;
import '../../config/data_source_config.dart';

extension TemporaryTargetDriftMapper on domain.TemporaryTarget {
  drift.TemporaryTargetCompanion toCompanion(TreatmentsSource source) {
    return drift.TemporaryTargetCompanion.insert(
      source: source.storageValue,
      externalId: source == TreatmentsSource.cloud && nightscoutId.isNotEmpty
          ? Value(nightscoutId)
          : const Value.absent(),
      createdAt: Value(createdAt.millisecondsSinceEpoch),
      nightscoutId: Value(nightscoutId),
      durationMinutes: Value(duration),
      targetBottom: Value(targetBottom.toDouble()),
      targetTop: Value(targetTop.toDouble()),
    );
  }
}

extension TemporaryTargetDomainMapper on drift.TemporaryTargetData {
  domain.TemporaryTarget toDomain() {
    final duration = durationMinutes ?? 0;

    return domain.TemporaryTarget(
      nightscoutId: nightscoutId ?? externalId ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      durationInMiliseconds: Duration(minutes: duration).inMilliseconds,
      duration: duration,
      targetBottom: targetBottom?.round() ?? 0,
      targetTop: targetTop?.round() ?? 0,
    );
  }
}
