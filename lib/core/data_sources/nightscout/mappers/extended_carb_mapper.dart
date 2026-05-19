import '../../../domain/model/extended_carb.dart';
import '../dto/extended_carb_dto.dart';

extension ExtendedCarbMapper on ExtendedCarbDto {
  ExtendedCarb toDomain() {
    return ExtendedCarb(
      externalId: id,
      createdAt: DateTime.parse(createdAt).toLocal(),
      carbs: (carbs as num?)?.toInt() ?? 0,
      duration: (duration as num?)?.toInt() ?? 0,
      isValid: isValid,
    );
  }
}
