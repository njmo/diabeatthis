import '../../../domain/model/glucose.dart';
import '../dto/glucose_dto.dart';

extension GlucoseMapper on GlucoseDto {
  Glucose toDomain() {
    return Glucose(
      externalId: id,
      source: GlucoseSource.cloud,
      date: DateTime.fromMillisecondsSinceEpoch(date),
      sgv: (sgv as num?)?.toInt() ?? 0,
      direction: direction,
    );
  }
}
