import 'package:diabeatthis/common/devices/cgm_sensor_type.dart';
import 'package:diabeatthis/common/devices/insulin_pump_type.dart';
import 'package:diabeatthis/common/devices/presentation/device_status_hud_pills.dart';
import 'package:diabeatthis/common/devices/presentation/pump_silhouette_icon.dart';
import 'package:diabeatthis/common/devices/presentation/sensor_silhouette_icon.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device Silhouette Icons & HUD Pills', () {
    testWidgets('renders sensor silhouettes without throwing', (tester) async {
      for (final sensor in CgmSensorType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SensorSilhouetteIcon(type: sensor, size: 24),
            ),
          ),
        );
        expect(find.byType(SensorSilhouetteIcon), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders pump silhouettes without throwing', (tester) async {
      for (final pump in InsulinPumpType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PumpSilhouetteIcon(type: pump, size: 24),
            ),
          ),
        );
        expect(find.byType(PumpSilhouetteIcon), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders DeviceStatusHudPills with sensor and pump labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorAgeProvider.overrideWith(
              (ref) => Future.value(const Duration(days: 3, hours: 2)),
            ),
            canulaAgeProvider.overrideWith(
              (ref) => Future.value(const Duration(days: 1, hours: 5)),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceStatusHudPills(
                sensorType: CgmSensorType.dexcomG7,
                pumpType: InsulinPumpType.ypsopump,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DeviceStatusHudPills), findsOneWidget);
      expect(find.byType(SensorSilhouetteIcon), findsOneWidget);
      expect(find.byType(PumpSilhouetteIcon), findsOneWidget);
      expect(find.text('3 dni'), findsOneWidget);
      expect(find.text('1 dzień'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders device short names when age is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorAgeProvider.overrideWith((ref) => Future.value(null)),
            canulaAgeProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceStatusHudPills(
                sensorType: CgmSensorType.dexcomG7,
                pumpType: InsulinPumpType.ypsopump,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('G7'), findsOneWidget);
      expect(find.text('Ypso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
