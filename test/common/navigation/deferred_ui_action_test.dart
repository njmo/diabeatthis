import 'dart:async';

import 'package:diabeatthis/common/navigation/deferred_ui_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'queues before UI readiness and suppresses duplicate open requests',
    (tester) async {
      BuildContext? readyContext;
      final opened = <int>[];
      final close = Completer<void>();
      final launcher = DeferredUiAction<int>(
        getContext: () => readyContext,
        open: (_, id) async {
          opened.add(id);
          await close.future;
        },
      );
      addTearDown(launcher.dispose);
      launcher.request(7);
      await tester.pump();
      expect(opened, isEmpty);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              readyContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      launcher.retryPending();
      await tester.pump();
      launcher.request(7);
      await tester.pump();
      expect(opened, [7]);
      close.complete();
      await tester.pump();
    },
  );

  testWidgets('disposed launcher never opens a stale completion screen', (
    tester,
  ) async {
    final opened = <int>[];
    final launcher = DeferredUiAction<int>(
      getContext: () => null,
      open: (_, id) async => opened.add(id),
    );
    launcher.request(7);
    launcher.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(opened, isEmpty);
  });
}
