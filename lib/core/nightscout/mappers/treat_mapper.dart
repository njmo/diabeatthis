import '../../domain/model/treat.dart';
import '../dto/treat_dto.dart';

extension TreatMapper on TreatDto {
  Treat toDomain({int? localId}) {

    return Treat(
      id: 0,
      dateHappened: DateTime.parse(created_at).toLocal(),
      carbs: (carbs as num?)?.toInt() ?? 0,
    );
  }
}
