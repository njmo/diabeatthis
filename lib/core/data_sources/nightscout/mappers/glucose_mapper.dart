import '../../../domain/model/glucose.dart';
import '../dto/glucose_dto.dart';

extension GlucoseMapper on GlucoseDto {
  Glucose toDomain({int? localId}) {
    return Glucose(
      id: localId ?? 0,
      externalId: null,
      source: GlucoseSource.cloud,
      date: DateTime.parse(createdAt).toLocal(),
      sgv: (sgv as num?)?.toInt() ?? 0,
      direction: direction,
    );
  }
}
