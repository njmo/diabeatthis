import 'dart:async';

import 'package:diabeatthis/common/treatments/native_treatment_payloads.dart';
import 'package:diabeatthis/common/treatments/raw_treatment_batch_buffer.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final carbs = {'eventType': 'Meal Bolus', 'carbs': 48};
  final wizard = {'eventType': 'Bolus Wizard'};
  final delivery = {'eventType': 'Meal Bolus', 'insulin': 3};

  test('standalone carbs settle after one second', () {
    fakeAsync((async) {
      final batches = <List<Map<String, dynamic>>>[];
      final buffer = RawTreatmentBatchBuffer(
        onBatch: (batch) async => batches.add(batch),
        onError: (error, stack) => fail('$error'),
      );
      buffer.add([carbs]);
      async.elapse(const Duration(milliseconds: 999));
      expect(batches, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(batches, [
        [carbs],
      ]);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('wizard extends grace until delivery and collects following carbs', () {
    fakeAsync((async) {
      final batches = <List<Map<String, dynamic>>>[];
      final buffer = RawTreatmentBatchBuffer(
        onBatch: (batch) async => batches.add(batch),
        onError: (error, stack) => fail('$error'),
      );
      buffer.add([carbs]);
      async.elapse(const Duration(milliseconds: 800));
      buffer.add([wizard]);
      async.elapse(const Duration(seconds: 7));
      expect(batches, isEmpty);
      buffer.add([delivery]);
      async.elapse(const Duration(milliseconds: 999));
      expect(batches, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(batches, [
        [carbs, wizard, delivery],
      ]);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('wizard first collects insulin then slightly later carbs', () {
    fakeAsync((async) {
      final batches = <List<Map<String, dynamic>>>[];
      final buffer = RawTreatmentBatchBuffer(
        onBatch: (batch) async => batches.add(batch),
        onError: (error, stack) => fail('$error'),
      );
      buffer.add([wizard]);
      async.elapse(const Duration(seconds: 7));
      buffer.add([delivery]);
      async.elapse(const Duration(milliseconds: 49));
      buffer.add([carbs]);
      async.elapse(const Duration(seconds: 1));
      expect(batches, [
        [wizard, delivery, carbs],
      ]);
    });
  });

  test('missing or invalid delivery cannot extend the ten second deadline', () {
    fakeAsync((async) {
      final batches = <List<Map<String, dynamic>>>[];
      final buffer = RawTreatmentBatchBuffer(
        onBatch: (batch) async => batches.add(batch),
        onError: (error, stack) => fail('$error'),
      );
      buffer.add([wizard]);
      async.elapse(const Duration(seconds: 9));
      buffer.add([
        {...delivery, 'isValid': false},
        carbs,
      ]);
      async.elapse(const Duration(seconds: 1));
      expect(batches, hasLength(1));
      expect(batches.single, hasLength(3));
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('flush awaits writes in arrival order and removes all timers', () {
    fakeAsync((async) {
      final batches = <List<Map<String, dynamic>>>[];
      final firstWrite = Completer<void>();
      final buffer = RawTreatmentBatchBuffer(
        onBatch: (batch) async {
          batches.add(batch);
          if (batches.length == 1) await firstWrite.future;
        },
        onError: (error, stack) => fail('$error'),
      );
      buffer.add([carbs]);
      buffer.flush();
      async.flushMicrotasks();
      buffer.add([wizard, delivery]);
      var completed = false;
      buffer.flush().then((_) => completed = true);
      async.flushMicrotasks();
      expect(batches, hasLength(1));
      expect(completed, isFalse);
      firstWrite.complete();
      async.flushMicrotasks();
      expect(batches, [
        [carbs],
        [wizard, delivery],
      ]);
      expect(completed, isTrue);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('reports a failed batch and continues accepting later batches', () {
    fakeAsync((async) {
      final errors = <Object>[];
      var writes = 0;
      final buffer = RawTreatmentBatchBuffer(
        onBatch: (_) async {
          writes++;
          if (writes == 1) throw StateError('Failed write');
        },
        onError: (error, stack) => errors.add(error),
      );
      buffer.add([carbs]);
      async.elapse(const Duration(seconds: 1));
      buffer.add([delivery]);
      async.elapse(const Duration(seconds: 1));
      expect(writes, 2);
      expect(errors, hasLength(1));
    });
  });

  test('publishes only pending wizards once while retaining the raw triad', () {
    fakeAsync((async) {
      final batches = <List<Map<String, dynamic>>>[];
      final pending = <List<Map<String, dynamic>>>[];
      final buffer = RawTreatmentBatchBuffer(
        onBatch: (batch) async => batches.add(batch),
        onPendingWizards: (records) async => pending.add(records),
        onError: (error, stack) => fail('$error'),
      );
      buffer.add([carbs, wizard]);
      async.elapse(const Duration(seconds: 1));
      expect(pending, [
        [wizard],
      ]);
      expect(batches, isEmpty);
      buffer.add([Map<String, dynamic>.of(wizard)]);
      async.elapse(const Duration(seconds: 1));
      expect(pending, hasLength(1));
      // Repeated broadcasts must not prevent the hard deadline from flushing.
      async.elapse(const Duration(seconds: 8));
      expect(batches.single, [carbs, wizard, wizard]);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('extracts direct, wrapped and list payloads without parsing', () {
    for (final payload in [
      carbs,
      {'data': carbs},
      {
        'data': [carbs, wizard],
      },
    ]) {
      final event = {
        'external_event': 'native_receiver',
        'data': {'kind': 'treatments', 'data': payload},
      };
      final extracted = nativeTreatmentPayloads(event)!;
      expect(extracted.first, carbs);
    }
    expect(nativeTreatmentPayloads({'external_event': 'app_event'}), isNull);
    expect(
      nativeTreatmentPayloads({
        'external_event': 'native_receiver',
        'data': {'kind': 'glucose', 'data': carbs},
      }),
      isNull,
    );
    expect(
      () => nativeTreatmentPayloads({
        'external_event': 'native_receiver',
        'data': {
          'kind': 'treatments',
          'data': {
            'data': [42],
          },
        },
      }),
      throwsFormatException,
    );
  });
}
