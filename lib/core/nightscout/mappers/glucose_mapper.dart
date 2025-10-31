import '../../domain/model/glucose.dart';
import '../dto/glucose_dto.dart';

extension GlucoseMapper on GlucoseDto {
  Glucose toDomain({int? localId}) {

    return Glucose(
      id: 0,
      date: DateTime.parse(created_at).toLocal(),
      sgv: (sgv as num?)?.toInt() ?? 0,
      direction: direction,
    );
  }
}
