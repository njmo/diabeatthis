import 'dart:async';

import 'package:diabeatthis/features/activity/common/controllers/serialized_status_action_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/test_status_action_controller.dart';

void main() {
  final provider =
      NotifierProvider<SerializedStatusActionController, AsyncValue<void>>(
        TestStatusActionController.new,
      );
  test(
    'concurrent mutation is rejected before executing its side effects',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(provider.notifier);
      final pending = Completer<int>();
      final first = controller.execute(() => pending.future);
      var duplicateExecuted = false;
      await expectLater(
        controller.execute(() async {
          duplicateExecuted = true;
          return 99;
        }),
        throwsStateError,
      );
      expect(duplicateExecuted, false);
      expect(container.read(provider).isLoading, true);
      pending.complete(42);
      expect(await first, 42);
      expect(container.read(provider), const AsyncData<void>(null));
    },
  );
  test(
    'failure remains visible; retry executes once and clears error',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(provider.notifier);
      final failure = StateError('Mocked write failed');
      await expectLater(
        controller.execute(() async => throw failure),
        throwsA(same(failure)),
      );
      expect(container.read(provider).error, same(failure));
      expect(await controller.execute(() async => 'saved'), 'saved');
      expect(container.read(provider), const AsyncData<void>(null));
    },
  );
  test(
    'completion after disposal returns the result without writing disposed state',
    () async {
      final container = ProviderContainer();
      final pending = Completer<int>();
      final result = container
          .read(provider.notifier)
          .execute(() => pending.future);
      container.dispose();
      pending.complete(7);
      expect(await result, 7);
    },
  );
}
