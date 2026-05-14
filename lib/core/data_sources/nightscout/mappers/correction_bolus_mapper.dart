import '../../../domain/model/correction_bolus.dart';
import '../dto/correction_bolus_dto.dart';

extension CorrectionBolusMapper on CorrectionBolusDto {
  CorrectionBolus toDomain() {
    return CorrectionBolus(
      externalId: id,
      createdAt: DateTime.parse(createdAt).toLocal(),
      insulin: (insulin as num?)?.toDouble() ?? 0,
    );
  }
}
