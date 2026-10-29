import 'dart:io';

import 'package:diabeatthis/common/temporary_targets/owned_temp_target.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_operation.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_proposal.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_operation_repository.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    hide TempTargetOperation;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 12);
  late DatabaseImpl db;
  late TempTargetOperationRepository repository;

  TempTargetProposal proposal(
    String id, {
    int entityId = 1,
    String type = 'activity',
    String source = 'https://nightscout.example',
  }) => TempTargetProposal(
    id: id,
    entityId: entityId,
    targetType: type,
    target: 140,
    durationMinutes: 90,
    expiresAt: now.add(const Duration(minutes: 5)),
    source: source,
  );

  OwnedTempTarget target({
    int entityId = 1,
    DateTime? start,
    String type = 'activity',
    String? nightscoutId,
    String source = 'https://nightscout.example',
  }) {
    final startedAt = start ?? now;
    return OwnedTempTarget(
      entityId: entityId,
      targetType: type,
      source: source,
      startedAt: startedAt,
      until: startedAt.add(const Duration(minutes: 90)),
      target: 140,
      durationMinutes: 90,
      nightscoutId: nightscoutId,
    );
  }

  Future<void> confirm(String id, OwnedTempTarget owned) async {
    await repository.createOffer(
      proposal(
        id,
        entityId: owned.entityId,
        type: owned.targetType,
        source: owned.source,
      ),
      now: owned.startedAt,
    );
    expect(
      await repository.claimStart(id, owned, now: owned.startedAt),
      isTrue,
    );
    expect(
      await repository.markSent(id, confirmed: owned, now: owned.startedAt),
      isTrue,
    );
  }

  Future<void> seedEntities(DatabaseImpl database) async {
    final activityId = await database
        .into(database.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Activity',
            percentagePre: 0,
            percentagePost: 0,
          ),
        );
    for (var i = 0; i < 2; i++) {
      await database
          .into(database.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activityId,
              startedAt: now.millisecondsSinceEpoch,
            ),
          );
      await database
          .into(database.meal)
          .insert(
            MealCompanion.insert(
              name: 'Meal $i',
              plannedAt: now
                  .add(const Duration(minutes: 15))
                  .millisecondsSinceEpoch,
            ),
          );
    }
  }

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    repository = TempTargetOperationRepository(db);
    await seedEntities(db);
  });
  tearDown(() => db.close());

  for (final closure in ['ended', 'deleted']) {
    test('an activity $closure after its offer cannot be claimed', () async {
      await repository.createOffer(proposal('closed'), now: now);
      if (closure == 'ended') {
        await db.activityDao.finishActivityLogIfOpen(
          1,
          now,
          now.add(const Duration(minutes: 1)),
        );
      } else {
        await (db.delete(
          db.activityLog,
        )..where((row) => row.id.equals(1))).go();
      }
      expect(
        await repository.claimStart('closed', target(), now: now),
        isFalse,
      );
      final operation = (await repository.get('closed'))!;
      expect(operation.closedAt, isNotNull);
      expect(operation.attemptedTarget, isNull);
      expect(operation.status, TempTargetOperationStatus.pendingDelivery);
      expect(await repository.unresolvedSends(), isEmpty);
    });
  }

  test(
    'a stale offer with no closure marker still rechecks its activity row',
    () async {
      await db.activityDao.finishActivityLogIfOpen(
        1,
        now,
        now.add(const Duration(minutes: 1)),
      );
      await repository.createOffer(proposal('stale'), now: now);
      expect((await repository.get('stale'))!.closedAt, isNull);
      expect(await repository.claimStart('stale', target(), now: now), isFalse);
      await (db.delete(db.activityLog)..where((row) => row.id.equals(2))).go();
      await repository.createOffer(proposal('missing', entityId: 2), now: now);
      expect((await repository.get('missing'))!.closedAt, isNull);
      expect(
        await repository.claimStart('missing', target(entityId: 2), now: now),
        isFalse,
      );
      expect(await repository.unresolvedSends(), isEmpty);
    },
  );

  test('a meal no longer planned after its offer cannot be claimed', () async {
    await repository.createOffer(proposal('meal', type: 'meal'), now: now);
    await (db.update(db.meal)..where((row) => row.id.equals(1))).write(
      const MealCompanion(status: Value('eaten')),
    );
    expect(
      await repository.claimStart('meal', target(type: 'meal'), now: now),
      isFalse,
    );
    expect((await repository.get('meal'))!.attemptedTarget, isNull);
    expect(await repository.unresolvedSends(), isEmpty);
  });

  test('a meal removed after its offer cannot be claimed', () async {
    await repository.createOffer(proposal('meal', type: 'meal'), now: now);
    await (db.delete(db.meal)..where((row) => row.id.equals(1))).go();
    expect(
      await repository.claimStart('meal', target(type: 'meal'), now: now),
      isFalse,
    );
    expect((await repository.get('meal'))!.attemptedTarget, isNull);
    expect(await repository.unresolvedSends(), isEmpty);
  });

  test(
    'offer creation retains failed delivery and does not overwrite a delivered request',
    () async {
      final original = await repository.createOffer(
        proposal('offer'),
        now: now,
      );
      expect(original.status, TempTargetOperationStatus.pendingDelivery);
      expect(original.deliveredAt, isNull);
      await repository.createOffer(
        proposal('offer', entityId: 2),
        now: now.add(const Duration(minutes: 1)),
      );
      expect((await repository.get('offer'))!.entityId, 1);
      final deliveredAt = now.add(const Duration(seconds: 5));
      expect(await repository.markDelivered('offer', now: deliveredAt), isTrue);
      expect(
        await repository.markDelivered(
          'offer',
          now: now.add(const Duration(seconds: 6)),
        ),
        isFalse,
      );
      final delivered = (await repository.get('offer'))!;
      expect(delivered.status, TempTargetOperationStatus.awaitingConsent);
      expect(delivered.deliveredAt, deliveredAt);
      expect(delivered.createdAt, now);
    },
  );

  test(
    'latest offer separates meals from activities with the same entity ID',
    () async {
      await repository.createOffer(proposal('activity'), now: now);
      await repository.createOffer(
        proposal('meal', type: 'meal'),
        now: now.add(const Duration(seconds: 1)),
      );
      expect(
        (await repository.latestStart(
          entityId: 1,
          source: target().source,
          targetType: 'activity',
        ))!.requestId,
        'activity',
      );
      expect(
        (await repository.latestStart(
          entityId: 1,
          source: target().source,
          targetType: 'meal',
        ))!.requestId,
        'meal',
      );
    },
  );

  test('offers created in the same millisecond keep insertion order', () async {
    await repository.createOffer(proposal('z-first'), now: now);
    await repository.createOffer(proposal('a-second'), now: now);
    expect(
      (await repository.latestStart(
        entityId: 1,
        source: target().source,
      ))!.requestId,
      'a-second',
    );
  });

  test(
    'competing approvals claim once and persist the attempt before remote delivery',
    () async {
      await repository.createOffer(proposal('first'), now: now);
      final other = TempTargetOperationRepository(db);
      final results = await Future.wait([
        repository.claimStart('first', target(), now: now),
        other.claimStart('first', target(), now: now),
      ]);
      expect(results.where((result) => result), hasLength(1));
      final operation = (await repository.get('first'))!;
      expect(operation.status, TempTargetOperationStatus.sending);
      expect(operation.attemptedTarget!.startedAt, now);
      expect(operation.confirmedTarget, isNull);
      expect(await repository.latestOwned(), isNull);
    },
  );

  test(
    'concurrent approval of different offers permits only one remote attempt',
    () async {
      await repository.createOffer(proposal('first'), now: now);
      await repository.createOffer(proposal('second', entityId: 2), now: now);
      final other = TempTargetOperationRepository(db);
      final results = await Future.wait([
        repository.claimStart('first', target(), now: now),
        other.claimStart(
          'second',
          target(entityId: 2, start: now.add(const Duration(seconds: 1))),
          now: now,
        ),
      ]);
      expect(results.where((result) => result), hasLength(1));
      expect(await repository.unresolvedSends(), hasLength(1));
    },
  );

  test(
    'ambiguous result blocks another send until reconciliation resolves it',
    () async {
      await repository.createOffer(proposal('first'), now: now);
      expect(await repository.claimStart('first', target(), now: now), isTrue);
      expect(await repository.markUnknownResult('first', now: now), isTrue);
      await repository.createOffer(
        proposal('second', entityId: 2),
        now: now.add(const Duration(minutes: 1)),
      );
      expect(
        await repository.claimStart(
          'second',
          target(entityId: 2, start: now.add(const Duration(minutes: 1))),
        ),
        isFalse,
      );
      expect((await repository.unresolvedSends()).single.requestId, 'first');
      expect(await repository.markRejected('first', now: now), isTrue);
      expect(
        await repository.claimStart(
          'second',
          target(entityId: 2, start: now.add(const Duration(minutes: 1))),
        ),
        isTrue,
      );
      expect(
        await repository.claimStart(
          'first',
          target(start: now.add(const Duration(minutes: 2))),
        ),
        isFalse,
      );
    },
  );

  test(
    'timestamps less than one second apart are not claimed across start and stop',
    () async {
      await confirm('first', target());
      await repository.createStop(
        requestId: 'too-early',
        owned: target(),
        stoppedAt: now.add(const Duration(milliseconds: 999)),
        now: now,
      );
      expect(await repository.claimStop('too-early'), isFalse);
      await repository.createStop(
        requestId: 'stop',
        owned: target(),
        stoppedAt: now.add(const Duration(seconds: 1)),
        now: now,
      );
      expect(await repository.claimStop('stop'), isTrue);
      expect(
        await repository.latestAttemptAt(target().source),
        now.add(const Duration(seconds: 1)),
      );
    },
  );

  test(
    'a later rejected request does not block a historical cancellation time',
    () async {
      await confirm('first', target());
      await repository.createOffer(
        proposal('rejected'),
        now: now.add(const Duration(minutes: 10)),
      );
      await repository.claimStart(
        'rejected',
        target(start: now.add(const Duration(minutes: 10))),
      );
      await repository.markRejected('rejected');
      final stoppedAt = now.add(const Duration(minutes: 5));
      await repository.createStop(
        requestId: 'stop',
        owned: target(),
        stoppedAt: stoppedAt,
      );
      expect(await repository.claimStop('stop'), isTrue);
      expect((await repository.get('stop'))!.stoppedAt, stoppedAt);
    },
  );

  test('source changes preserve independent confirmed ownership', () async {
    await confirm('first', target());
    await confirm(
      'other',
      target(
        source: 'https://other.example',
        start: now.add(const Duration(minutes: 1)),
      ),
    );
    expect(
      (await repository.latestOwned(source: target().source))!.startedAt,
      now,
    );
    expect(
      (await repository.get('first'))!.status,
      TempTargetOperationStatus.sent,
    );
    expect(
      (await repository.latestOwned(source: 'https://other.example'))!.source,
      'https://other.example',
    );
  });

  test(
    'an unresolved request on another host does not block the current host',
    () async {
      await repository.createOffer(proposal('first'), now: now);
      await repository.claimStart('first', target(), now: now);
      await repository.markUnknownResult('first', now: now);
      await repository.createOffer(
        proposal('other', source: 'https://other.example'),
        now: now,
      );
      expect(
        await repository.claimStart(
          'other',
          target(source: 'https://other.example'),
          now: now,
        ),
        isTrue,
      );
      expect(await repository.unresolvedSends(), hasLength(2));
    },
  );

  test(
    'confirming a new target supersedes ownership and a stop completes only its owner',
    () async {
      final first = target(nightscoutId: 'first');
      final second = target(
        entityId: 2,
        type: 'meal',
        start: now.add(const Duration(minutes: 2)),
        nightscoutId: 'second',
      );
      await confirm('first', first);
      await confirm('second', second);
      expect(
        (await repository.get('first'))!.status,
        TempTargetOperationStatus.superseded,
      );
      expect((await repository.latestOwned())!.nightscoutId, 'second');
      await repository.createStop(
        requestId: 'old-stop',
        owned: first,
        stoppedAt: now.add(const Duration(minutes: 3)),
        now: now,
      );
      expect(await repository.claimStop('old-stop'), isTrue);
      expect(await repository.markSent('old-stop'), isTrue);
      expect((await repository.latestOwned())!.nightscoutId, 'second');
      await repository.createStop(
        requestId: 'stop',
        owned: second,
        stoppedAt: now.add(const Duration(minutes: 4)),
        now: now,
      );
      expect(await repository.claimStop('stop'), isTrue);
      expect(await repository.markSent('stop'), isTrue);
      expect(
        (await repository.get('second'))!.status,
        TempTargetOperationStatus.completed,
      );
      expect(await repository.latestOwned(), isNull);
    },
  );

  test(
    'expired unresolved operation is completed without inventing ownership',
    () async {
      await repository.createOffer(proposal('first'), now: now);
      await repository.claimStart('first', target(), now: now);
      expect(
        await repository.completeOperation(
          'first',
          now: now.add(const Duration(hours: 2)),
        ),
        isTrue,
      );
      expect(
        (await repository.get('first'))!.status,
        TempTargetOperationStatus.completed,
      );
      expect(await repository.latestOwned(), isNull);
      expect(await repository.unresolvedSends(), isEmpty);
    },
  );

  test(
    'expired ambiguous stop completes only its original ownership',
    () async {
      await confirm('first', target());
      await repository.createStop(
        requestId: 'stop',
        owned: target(),
        stoppedAt: now.add(const Duration(minutes: 10)),
        now: now,
      );
      await repository.claimStop('stop', now: now);
      await repository.markUnknownResult('stop', now: now);
      expect(
        await repository.completeOperation(
          'stop',
          now: now.add(const Duration(hours: 2)),
        ),
        isTrue,
      );
      expect(
        (await repository.get('first'))!.status,
        TempTargetOperationStatus.completed,
      );
      expect(await repository.latestOwned(), isNull);
      expect(await repository.unresolvedSends(), isEmpty);
    },
  );

  test(
    'activity closure persists its actual end and survives a later deletion',
    () async {
      final activityId = await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Run',
              percentagePre: 0,
              percentagePost: 0,
            ),
          );
      final logId = await db
          .into(db.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activityId,
              startedAt: now.millisecondsSinceEpoch,
            ),
          );
      await confirm('first', target(entityId: logId));
      final endedAt = now.add(const Duration(minutes: 20));
      await (db.update(
        db.activityLog,
      )..where((row) => row.id.equals(logId))).write(
        ActivityLogCompanion(endedAt: Value(endedAt.millisecondsSinceEpoch)),
      );
      expect((await repository.latestOwnedOperation())!.closedAt, endedAt);
      await (db.delete(
        db.activityLog,
      )..where((row) => row.id.equals(logId))).go();
      expect((await repository.latestOwnedOperation())!.closedAt, endedAt);
      expect(
        await repository.closeActivity(
          logId,
          now.add(const Duration(minutes: 30)),
        ),
        isFalse,
      );
    },
  );

  test(
    'deleting an unfinished activity retains its owner and a stable closure time',
    () async {
      final activityId = await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Run',
              percentagePre: 0,
              percentagePost: 0,
            ),
          );
      final logId = await db
          .into(db.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activityId,
              startedAt: now.millisecondsSinceEpoch,
            ),
          );
      await confirm('first', target(entityId: logId));
      await (db.delete(
        db.activity,
      )..where((row) => row.id.equals(activityId))).go();
      final operation = (await repository.latestOwnedOperation())!;
      expect(operation.closedAt, isNotNull);
      expect(operation.confirmedTarget!.entityId, logId);
      expect(await repository.closeActivity(logId, now), isFalse);
      expect(
        (await repository.latestOwnedOperation())!.closedAt,
        operation.closedAt,
      );
    },
  );

  test(
    'legacy ownership migration does not resurrect a completed record',
    () async {
      await repository.importConfirmedOwned(target(), now: now);
      expect((await repository.latestOwned())!.startedAt, now);
      await repository.completeOwned(target(), now: now);
      await repository.importConfirmedOwned(target(), now: now);
      expect(await repository.latestOwned(), isNull);
      expect(await repository.list(), hasLength(1));
    },
  );

  test(
    'pending offers do not prevent migration of existing ownership',
    () async {
      await repository.createOffer(
        proposal('pending'),
        now: now.add(const Duration(minutes: 1)),
      );
      await repository.importConfirmedOwned(target(), now: now);
      expect((await repository.latestOwned())!.startedAt, now);
      expect(await repository.list(), hasLength(2));
    },
  );

  test(
    'a restart preserves an ambiguous attempt and its original immutable payload',
    () async {
      await db.close();
      final directory = await Directory.systemTemp.createTemp(
        'temp-target-operations-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final firstDatabase = DatabaseImpl(NativeDatabase(file));
      await seedEntities(firstDatabase);
      final firstRepository = TempTargetOperationRepository(firstDatabase);
      await firstRepository.createOffer(proposal('durable'), now: now);
      await firstRepository.markDelivered('durable', now: now);
      await firstRepository.claimStart('durable', target(), now: now);
      await firstDatabase.close();
      final reopened = DatabaseImpl(NativeDatabase(file));
      db = reopened;
      final durable = TempTargetOperationRepository(reopened);
      final operation = (await durable.unresolvedSends()).single;
      expect(operation.requestId, 'durable');
      expect(operation.deliveredAt, now);
      expect(operation.proposal!.durationMinutes, 90);
      expect(operation.attemptedTarget!.until, target().until);
      expect(
        await durable.markSent(
          'durable',
          confirmed: target(nightscoutId: 'remote-id'),
          now: now,
        ),
        isTrue,
      );
      expect((await durable.latestOwned())!.nightscoutId, 'remote-id');
    },
  );
}
