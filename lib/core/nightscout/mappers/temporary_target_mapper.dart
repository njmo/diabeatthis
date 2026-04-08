import '../../domain/model/temporary_target.dart';
import '../dto/temporary_target_dto.dart';

extension TemporaryTargetMapper on TemporaryTargetDto {
  TemporaryTarget toDomain({int? localId}) {
    return TemporaryTarget(
      id: 0,
      nightscoutId: nightscoutId,
      createdAt: DateTime.parse(createdAt).toLocal(),
      durationInMiliseconds: durationInMilliseconds,
      duration: duration,
      targetBottom: targetBottom,
      targetTop: targetTop,
    );
  }
}