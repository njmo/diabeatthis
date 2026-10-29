import 'package:diabeatthis/common/temporary_targets/owned_temp_target.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_operation.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_proposal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 29, 17, 30, 0, 123, 456);
  final end = start.add(const Duration(minutes: 90));
  final owned = OwnedTempTarget(
    entityId: 1,
    targetType: 'activity',
    source: 'https://example.com',
    startedAt: start,
    until: end,
    target: 140,
    durationMinutes: 90,
  );

  test(
    'ownership persists absolute timestamps with timezone and precision',
    () {
      final json = owned.toJson();
      expect(json['startedAt'], start.toUtc().toIso8601String());
      expect(json['until'], end.toUtc().toIso8601String());
      expect(DateTime.parse(json['startedAt'] as String).isUtc, isTrue);
      final restored = OwnedTempTarget.fromJson(json);
      expect(restored.startedAt.isAtSameMomentAs(start), isTrue);
      expect(restored.until.isAtSameMomentAs(end), isTrue);
    },
  );

  test('UTC proposal still matches a session read in local time', () {
    final proposal = TempTargetProposal(
      id: 'request',
      entityId: 1,
      targetType: 'activity',
      target: 140,
      durationMinutes: 90,
      expiresAt: end,
      endsAt: end,
      durationEndsAt: end,
      source: 'https://example.com',
    );
    final json = proposal.toJson();
    for (final field in ['expiresAt', 'endsAt', 'durationEndsAt']) {
      expect(DateTime.parse(json[field] as String).isUtc, isTrue);
    }
    final restored = TempTargetProposal.fromJson(json);
    expect(restored.hasSameEnd(end.toLocal()), isTrue);
    expect(restored.hasSameEnd(end.toUtc()), isTrue);
    expect(restored.hasSameEnd(null), isFalse);
    expect(restored.durationAt(start), 90);
  });

  test('cancellation payload retains the absolute closure timestamp', () {
    final operation = TempTargetOperation(
      requestId: 'stop',
      kind: TempTargetOperationKind.stop,
      entityId: 1,
      targetType: 'activity',
      source: owned.source,
      status: TempTargetOperationStatus.sending,
      attemptedTarget: owned,
      stoppedAt: end,
      createdAt: end,
      updatedAt: end,
    );
    final stored = operation.payloadToJson()['stoppedAt'] as String;
    expect(DateTime.parse(stored).isUtc, isTrue);
    expect(DateTime.parse(stored).isAtSameMomentAs(end), isTrue);
  });
}
