import 'dart:async';

import 'package:diabeatthis/common/family_sync/family_plan_signal_listener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'permission failure permits a new subscription for the same account',
    () async {
      final listener = FamilyPlanSignalListener();
      addTearDown(listener.dispose);
      final beforePairing = StreamController<void>();
      final afterPairing = StreamController<void>();
      addTearDown(beforePairing.close);
      addTearDown(afterPairing.close);
      var changes = 0;
      var failures = 0;
      await listener.connect(
        'child',
        beforePairing.stream,
        onChange: () => changes++,
        onFailure: () => failures++,
      );
      beforePairing.addError(StateError('No family yet'));
      await Future<void>.delayed(Duration.zero);
      expect(listener.uid, isNull);
      expect(failures, 1);
      await listener.connect(
        'child',
        afterPairing.stream,
        onChange: () => changes++,
        onFailure: () => failures++,
      );
      afterPairing.add(null);
      await Future<void>.delayed(Duration.zero);
      afterPairing.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(changes, 2);
      expect(failures, 1);
    },
  );
}
