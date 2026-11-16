import 'cgm_sensor_type.dart';
import 'insulin_pump_type.dart';

class DeviceDetectionService {
  const DeviceDetectionService._();

  static CgmSensorType? _configuredSensor;
  static InsulinPumpType? _configuredPump;

  static void setConfiguredDevices({
    CgmSensorType? sensor,
    InsulinPumpType? pump,
  }) {
    _configuredSensor = sensor;
    _configuredPump = pump;
  }

  static CgmSensorType detectSensor(String? raw) {
    if (_configuredSensor != null) return _configuredSensor!;
    if (raw == null || raw.trim().isEmpty || raw.toLowerCase() == 'unknown') {
      return CgmSensorType.libre;
    }
    final lower = raw.toLowerCase();
    if (lower.contains('g7')) return CgmSensorType.dexcomG7;
    if (lower.contains('g6')) return CgmSensorType.dexcomG6;
    if (lower.contains('one')) return CgmSensorType.dexcomOne;
    if (lower.contains('dexcom') || lower.contains('share')) {
      return CgmSensorType.dexcom;
    }
    if (lower.contains('libre3') || lower.contains('libre 3')) {
      return CgmSensorType.libre3;
    }
    if (lower.contains('libre2') || lower.contains('libre 2')) {
      return CgmSensorType.libre2;
    }
    if (lower.contains('libre') ||
        lower.contains('diabox') ||
        lower.contains('juggluco')) {
      return CgmSensorType.libre;
    }
    if (lower.contains('guardian') ||
        lower.contains('minimed') ||
        lower.contains('medtronic')) {
      return CgmSensorType.guardian;
    }
    if (lower.contains('eversense')) return CgmSensorType.eversense;
    return CgmSensorType.libre2;
  }

  static InsulinPumpType detectPump({
    String? device,
    String? model,
    String? manufacturer,
  }) {
    if (_configuredPump != null) return _configuredPump!;
    final combined = '${device ?? ''} ${model ?? ''} ${manufacturer ?? ''}'
        .toLowerCase()
        .trim();
    if (combined.isEmpty || combined == 'unknown') {
      return InsulinPumpType.omnipod;
    }
    if (combined.contains('omnipod') ||
        combined.contains('pod') ||
        combined.contains('dash') ||
        combined.contains('eros') ||
        combined.contains('insulet')) {
      return InsulinPumpType.omnipod;
    }
    if (combined.contains('ypso') || combined.contains('mylife')) {
      return InsulinPumpType.ypsopump;
    }
    if (combined.contains('dana')) {
      return InsulinPumpType.dana;
    }
    if (combined.contains('medtronic') ||
        combined.contains('640') ||
        combined.contains('780') ||
        combined.contains('minimed')) {
      return InsulinPumpType.medtronic;
    }
    if (combined.contains('combo') ||
        combined.contains('roche') ||
        combined.contains('accu')) {
      return InsulinPumpType.combo;
    }
    return InsulinPumpType.omnipod;
  }

  static String formatAgeDuration(Duration? duration) {
    if (duration == null) return '—';
    final totalHours = duration.inHours;
    if (totalHours < 1) {
      return '${duration.inMinutes}m';
    }
    final days = duration.inDays;
    final hours = totalHours % 24;
    if (days >= 1) {
      return days == 1 ? '1 dzień' : '$days dni';
    }
    return '${hours}h';
  }
}
