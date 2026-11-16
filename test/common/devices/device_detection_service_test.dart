import 'package:diabeatthis/common/devices/cgm_sensor_type.dart';
import 'package:diabeatthis/common/devices/device_detection_service.dart';
import 'package:diabeatthis/common/devices/insulin_pump_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceDetectionService', () {
    test('detects Dexcom sensor variants correctly', () {
      expect(DeviceDetectionService.detectSensor('xDrip-DexcomG7'), CgmSensorType.dexcomG7);
      expect(DeviceDetectionService.detectSensor('Dexcom G7 (rev 2)'), CgmSensorType.dexcomG7);
      expect(DeviceDetectionService.detectSensor('Dexcom G6 Transmitter'), CgmSensorType.dexcomG6);
      expect(DeviceDetectionService.detectSensor('Dexcom ONE+'), CgmSensorType.dexcomOne);
      expect(DeviceDetectionService.detectSensor('Dexcom Share Receiver'), CgmSensorType.dexcom);
    });

    test('detects FreeStyle Libre sensor variants correctly', () {
      expect(DeviceDetectionService.detectSensor('Libre 3 Direct'), CgmSensorType.libre3);
      expect(DeviceDetectionService.detectSensor('Libre2-Juggluco'), CgmSensorType.libre2);
      expect(DeviceDetectionService.detectSensor('DiaBox Libre'), CgmSensorType.libre);
    });

    test('detects other CGM sensors correctly', () {
      expect(DeviceDetectionService.detectSensor('Medtronic Guardian 4'), CgmSensorType.guardian);
      expect(DeviceDetectionService.detectSensor('Eversense E3'), CgmSensorType.eversense);
      expect(DeviceDetectionService.detectSensor(null), CgmSensorType.libre);
      expect(DeviceDetectionService.detectSensor(''), CgmSensorType.libre);
      expect(DeviceDetectionService.detectSensor('unknown'), CgmSensorType.libre);
    });

    test('detects insulin pump types correctly', () {
      expect(
        DeviceDetectionService.detectPump(device: 'openaps://AndroidAPS/Ypsopump'),
        InsulinPumpType.ypsopump,
      );
      expect(
        DeviceDetectionService.detectPump(device: 'myLife YpsoPump BLE'),
        InsulinPumpType.ypsopump,
      );
      expect(
        DeviceDetectionService.detectPump(device: 'Omnipod DASH Pod'),
        InsulinPumpType.omnipod,
      );
      expect(
        DeviceDetectionService.detectPump(device: 'Insulet Omnipod 5'),
        InsulinPumpType.omnipod,
      );
      expect(
        DeviceDetectionService.detectPump(device: 'DanaRS v3'),
        InsulinPumpType.dana,
      );
      expect(
        DeviceDetectionService.detectPump(device: 'Medtronic 780G'),
        InsulinPumpType.medtronic,
      );
      expect(
        DeviceDetectionService.detectPump(device: 'Accu-Chek Combo'),
        InsulinPumpType.combo,
      );
      expect(
        DeviceDetectionService.detectPump(device: null),
        InsulinPumpType.omnipod,
      );
    });

    test('supports configured device overrides', () {
      DeviceDetectionService.setConfiguredDevices(
        sensor: CgmSensorType.dexcomG6,
        pump: InsulinPumpType.omnipod,
      );
      expect(DeviceDetectionService.detectSensor('anything'), CgmSensorType.dexcomG6);
      expect(DeviceDetectionService.detectPump(device: 'anything'), InsulinPumpType.omnipod);
      DeviceDetectionService.setConfiguredDevices(sensor: null, pump: null);
    });

    test('formats age duration properly', () {
      expect(DeviceDetectionService.formatAgeDuration(null), '—');
      expect(DeviceDetectionService.formatAgeDuration(const Duration(minutes: 25)), '25m');
      expect(DeviceDetectionService.formatAgeDuration(const Duration(hours: 4)), '4h');
      expect(DeviceDetectionService.formatAgeDuration(const Duration(days: 1, hours: 2)), '1 dzień');
      expect(DeviceDetectionService.formatAgeDuration(const Duration(days: 4, hours: 6)), '4 dni');
    });
  });
}
