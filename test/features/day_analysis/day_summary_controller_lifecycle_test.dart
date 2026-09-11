import 'dart:async';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_summary_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart'
    as domain;
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_summary_controller.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_summary_review_form.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_summary_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

class DeferredDaySummaryRepository extends DaySummaryRepository {
  final started = Completer<void>();
  final release = Completer<void>();
  bool fail = false;
  DeferredDaySummaryRepository(super.db);

  @override
  Future<void> insert(domain.AcceptedDaySummary summary) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    if (fail) throw StateError('Storage unavailable');
    await super.insert(summary);
  }
}

void main() {
  final date = DateTime(2020, 1, 1);
  final snapshot = DaySummarySnapshot(
    dayKey: '2020-01-01',
    asOf: DateTime(2020, 1, 2),
    builtAt: DateTime(2020, 1, 2, 8),
    utcOffsetMinutes: 60,
    metrics: {},
    limitations: [],
    review: [],
  );

  test(
    'saving notifier survives without listeners and blocks a second submission',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DeferredDaySummaryRepository(db);
      final container = ProviderContainer(
        overrides: [
          daySummaryRepositoryProvider.overrideWithValue(repo),
          daySummaryDraftProvider(date).overrideWith((ref) async => snapshot),
        ],
      );
      addTearDown(container.dispose);
      final provider = daySummaryControllerProvider(date);
      final controller = container.read(provider.notifier);
      final saving = controller.confirm(
        snapshot,
        skippedRecords: {},
        acknowledgeLimitations: false,
      );
      await repo.started.future;
      await container.pump();
      expect(container.read(provider.notifier), same(controller));
      expect(container.read(provider).isLoading, isTrue);
      await expectLater(
        container
            .read(provider.notifier)
            .confirm(
              snapshot,
              skippedRecords: {},
              acknowledgeLimitations: false,
            ),
        throwsStateError,
      );
      repo.release.complete();
      await saving;
      expect(
        (await repo.get(snapshot.dayKey))!.snapshot.encode(),
        snapshot.encode(),
      );
    },
  );

  test('write errors release saving state and allow retry', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DeferredDaySummaryRepository(db)..fail = true;
    repo.release.complete();
    final container = ProviderContainer(
      overrides: [
        daySummaryRepositoryProvider.overrideWithValue(repo),
        daySummaryDraftProvider(date).overrideWith((ref) async => snapshot),
      ],
    );
    addTearDown(container.dispose);
    final provider = daySummaryControllerProvider(date);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);
    await expectLater(
      controller.confirm(
        snapshot,
        skippedRecords: {},
        acknowledgeLimitations: false,
      ),
      throwsStateError,
    );
    expect(container.read(provider).isLoading, isFalse);
    expect(container.read(provider).hasError, isTrue);
    repo.fail = false;
    await controller.confirm(
      snapshot,
      skippedRecords: {},
      acknowledgeLimitations: false,
    );
    expect(container.read(provider).hasError, isFalse);
    expect(await repo.get(snapshot.dayKey), isNotNull);
  });
  testWidgets(
    'new draft cannot reenable acceptance while a previous save is running',
    (tester) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DeferredDaySummaryRepository(db);
      var current = snapshot;
      final container = ProviderContainer(
        overrides: [
          daySummaryRepositoryProvider.overrideWithValue(repo),
          daySummaryDraftProvider(date).overrideWith((ref) async => current),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(body: DaySummarySheet(date: date)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Zatwierdź podsumowanie'));
      await tester.tap(find.text('Zatwierdź podsumowanie'));
      await repo.started.future;
      current = DaySummarySnapshot(
        dayKey: snapshot.dayKey,
        asOf: snapshot.asOf,
        builtAt: snapshot.builtAt,
        utcOffsetMinutes: snapshot.utcOffsetMinutes,
        metrics: {DaySummaryMetric.mealCount: 1},
        limitations: [],
        review: [],
      );
      container.invalidate(daySummaryDraftProvider(date));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DaySummaryReviewForm>(find.byType(DaySummaryReviewForm))
            .snapshot
            .encode(),
        current.encode(),
      );
      expect(find.text('Zapisywanie…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      repo.release.complete();
      await container.read(daySummaryControllerProvider(date).future);
      await tester.pumpAndSettle();
      expect(
        (await repo.get(
          date.toIso8601String().substring(0, 10),
        ))!.snapshot.encode(),
        snapshot.encode(),
      );
      expect(find.text('Zatwierdź podsumowanie'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
