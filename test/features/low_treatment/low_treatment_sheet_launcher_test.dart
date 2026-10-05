import 'dart:async';

import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_sheet_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'coalesces requests until the sheet closes and allows reopening',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      var opens = 0;
      var closed = Completer<void>();
      final launcher = LowTreatmentSheetLauncher(
        getContext: () => context,
        openSheet: (_) {
          opens++;
          return closed.future;
        },
      );
      addTearDown(launcher.dispose);
      launcher.requestOpen();
      launcher.requestOpen();
      await tester.pump();
      launcher.requestOpen();
      launcher.retryPending();
      await tester.pump();
      expect(opens, 1);
      closed.complete();
      await tester.pump();
      closed = Completer<void>();
      launcher.requestOpen();
      await tester.pump();
      expect(opens, 2);
      closed.complete();
      await tester.pump();
    },
  );

  testWidgets('disposed launcher never looks up context from a queued frame', (
    tester,
  ) async {
    var lookups = 0;
    final launcher = LowTreatmentSheetLauncher(
      getContext: () {
        lookups++;
        return null;
      },
      openSheet: (_) async => fail('Must not open'),
    );
    launcher.requestOpen();
    launcher.dispose();
    await tester.pump();
    expect(lookups, 0);
  });

  testWidgets('dispose cancels navigator retry and later requests', (
    tester,
  ) async {
    var lookups = 0;
    final launcher = LowTreatmentSheetLauncher(
      getContext: () {
        lookups++;
        return null;
      },
      openSheet: (_) async => fail('Must not open'),
    );
    launcher.requestOpen();
    await tester.pump();
    expect(lookups, 1);
    launcher.dispose();
    launcher.retryPending();
    launcher.requestOpen();
    await tester.pump(const Duration(seconds: 6));
    expect(lookups, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens once when navigator becomes ready', (tester) async {
    BuildContext? context;
    var opens = 0;
    final launcher = LowTreatmentSheetLauncher(
      getContext: () => context,
      openSheet: (_) async {
        opens++;
      },
    );
    addTearDown(launcher.dispose);
    launcher.requestOpen();
    await tester.pump();
    expect(opens, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(opens, 1);
  });
}
