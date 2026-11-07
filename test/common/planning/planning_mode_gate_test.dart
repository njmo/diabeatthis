import 'dart:async';

import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/planning/planning_repository_provider.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final outcome in ['patient', 'caregiver', 'error']) {
    test(
      'local mutation waits for an explicit patient mode: $outcome',
      () async {
        final gate = Completer<ApplicationDeviceMode>();
        var databaseReads = 0;
        final container = ProviderContainer(
          overrides: [
            applicationDeviceModeProvider.overrideWith((_) => gate.future),
            databaseProvider.overrideWith((_) {
              databaseReads++;
              throw StateError('Database boundary reached');
            }),
          ],
        );
        addTearDown(container.dispose);
        final repository = container.read(planningRepositoryProvider);
        final result = repository.moveActivity(
          1,
          DateTime.now().add(const Duration(hours: 1)),
        );
        final expectation = expectLater(result, throwsA(anything));
        await Future<void>.delayed(Duration.zero);
        expect(databaseReads, 0);
        if (outcome == 'error') {
          gate.completeError(StateError('Mode unavailable'));
        } else {
          gate.complete(
            outcome == 'patient'
                ? ApplicationDeviceMode.patient
                : ApplicationDeviceMode.caregiver,
          );
        }
        await expectation;
        expect(databaseReads, outcome == 'patient' ? 1 : 0);
      },
    );
  }
}
