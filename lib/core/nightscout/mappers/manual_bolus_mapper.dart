import '../../domain/model/manual_bolus.dart';
import '../dto/manual_bolus_dto.dart';

extension ManualBolusMapper on ManualBolusDto {
  ManualBolus toDomain({int? localId}) {

    return ManualBolus(
      id: 0,
      dateHappened: DateTime.parse(created_at).toLocal(),
      insulin: (insulin as num?)?.toDouble() ?? 0,
    );
  }
}
