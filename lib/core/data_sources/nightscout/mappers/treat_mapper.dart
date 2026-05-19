import '../../../domain/model/treat.dart';
import '../dto/treat_dto.dart';

extension TreatMapper on TreatDto {
  Treat toDomain() {
    return Treat(
      externalId: id,
      createdAt: DateTime.parse(createdAt).toLocal(),
      carbs: (carbs as num?)?.toInt() ?? 0,
      isValid: isValid,
    );
  }
}
