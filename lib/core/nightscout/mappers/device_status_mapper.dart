import '../../domain/model/device_status.dart';
import '../dto/device_status_dto.dart';

extension DeviceStatusMapper on DeviceStatusDto {
  DeviceStatus toDomain({int? localId}) {
    final suggested =
        (openaps?['suggested'] as Map<String, dynamic>?) ?? const {};

    return DeviceStatus(
      id: 0,
      date: DateTime.parse(created_at).toLocal(),
      iob: (suggested['IOB'] as num?)?.toDouble() ?? 0,
      cob: (suggested['COB'] as num?)?.toDouble() ?? 0,
      tick: (suggested['tick'] as String?) ?? '',
      bg: (suggested['bg'] as num?)?.toInt() ?? 0,
    );
  }
}
