import '../../domain/model/correction_bolus.dart';
import '../dto/correction_bolus_dto.dart';

extension CorrectionBolusMapper on CorrectionBolusDto {
  CorrectionBolus toDomain({int? localId}) {

    return CorrectionBolus(
      id: 0,
      dateHappened: DateTime.parse(created_at).toLocal(),
      insulin: (insulin as num?)?.toDouble() ?? 0,
    );
  }
}
