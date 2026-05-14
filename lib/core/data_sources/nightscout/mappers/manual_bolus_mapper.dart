import '../../../domain/model/manual_bolus.dart';
import '../dto/manual_bolus_dto.dart';

extension ManualBolusMapper on ManualBolusDto {
  ManualBolus toDomain() {
    return ManualBolus(
      externalId: id,
      createdAt: DateTime.parse(createdAt).toLocal(),
      insulin: (insulin as num?)?.toDouble() ?? 0,
    );
  }
}
