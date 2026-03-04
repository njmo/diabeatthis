import '../../domain/model/temporary_target.dart';
import '../dto/temporary_target_dto.dart';

extension TemporaryTargetMapper on TemporaryTargetDto {
  TemporaryTarget toDomain({int? localId}) {
    return TemporaryTarget(
      createdAt: DateTime.parse(created_at).toLocal(),
      durationInMiliseconds: durationInMilliseconds,
      duration: duration,
      targetBottom: targetBottom,
      targetTop: targetTop,
    );
  }
}