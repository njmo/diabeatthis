import 'package:drift/drift.dart';

import '../../../domain/model/glucose.dart';
import '../../../drift/database_impl.dart';
import '../../config/data_source_config.dart';

extension LocalGlucoseMirrorMapper on Glucose {
  LocalGlucoseReadingCompanion toLocalMirrorCompanion(BgSource source) {
    return LocalGlucoseReadingCompanion.insert(
      source: source.storageValue,
      externalId: id > 0 ? Value(id.toString()) : const Value.absent(),
      recordedAt: date.millisecondsSinceEpoch,
      sgv: sgv,
      direction: Value(direction),
    );
  }
}
