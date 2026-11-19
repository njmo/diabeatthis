import 'dart:async';
import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/family_treatment_journal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

void main() {
  test(
    'prepare admission is checked under the writer before cancellation can pass it',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final journal = FamilyTreatmentJournal(db);
      final entered = Completer<void>(), release = Completer<void>();
      var allowed = true;
      final preparing = journal.prepare(
        uid: 'child',
        familyId: 'family',
        messageId: 'message',
        installationId: 'phone',
        proof: 'proof',
        authorized: () async {
          entered.complete();
          await release.future;
          return allowed;
        },
      );
      await entered.future;
      allowed = false;
      final cancellation = journal.cancelUnapplied('child');
      release.complete();
      await expectLater(preparing, throwsStateError);
      await cancellation;
      expect(await journal.find('child', 'family', 'message'), isNull);
    },
  );
  test(
    'older clinical journals gain a confirmation timestamp column without losing receipts',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute('''CREATE TABLE family_treatment_journal (
      claim_id TEXT PRIMARY KEY, owner_uid TEXT NOT NULL, family_id TEXT NOT NULL,
      message_id TEXT NOT NULL, installation_id TEXT NOT NULL, proof TEXT NOT NULL,
      meal_id INTEGER, applied_at INTEGER, acknowledged INTEGER NOT NULL DEFAULT 0,
      UNIQUE(family_id,message_id,owner_uid))''');
      raw.execute(
        "INSERT INTO family_treatment_journal VALUES('old','child','family','old-message','phone','proof',42,1000,1)",
      );
      final db = DatabaseImpl(NativeDatabase.opened(raw));
      addTearDown(db.close);
      final journal = FamilyTreatmentJournal(db);
      final old = await journal.get('old', 'child');
      expect(old!.mealId, 42);
      expect(old.acknowledged, true);
      expect(old.confirmedAt, isNull);
      expect(old.actualQuantity, isNull);
      expect(old.authorization, isNull);
      expect(old.cancelled, false);
      expect(
        (await db
                .customSelect(
                  'SELECT ack_attempt_order FROM family_treatment_journal',
                )
                .getSingle())
            .read<int>('ack_attempt_order'),
        0,
      );
      expect(await journal.pendingAcknowledgements('child'), isEmpty);
      final operation = await journal.prepare(
        uid: 'child',
        familyId: 'family',
        messageId: 'new',
        installationId: 'phone',
        proof: 'new-proof',
        confirmedAt: 1234,
      );
      expect(operation.confirmedAt, 1234);
    },
  );
  for (final finalCheck in [false, true]) {
    test(
      'authorization cannot finish beyond the lease: finalCheck=$finalCheck',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final journal = FamilyTreatmentJournal(db);
        final operation = await journal.prepare(
          uid: 'child',
          familyId: 'family',
          messageId: 'message',
          installationId: 'phone',
          proof: 'proof',
        );
        var elapsed = 0, checks = 0, saves = 0;
        await expectLater(
          journal.apply(
            operation,
            authorized: () async {
              checks++;
              if (checks == (finalCheck ? 2 : 1)) elapsed = 10000;
              return true;
            },
            elapsedMilliseconds: () => elapsed,
            deadlineMilliseconds: 10000,
            appliedAt: 1000,
            save: () async {
              saves++;
              await db.customStatement(
                "INSERT INTO meal(name,planned_at,status,purpose) VALUES('test',1000,'confirmed','lowTreatment')",
              );
              return 1;
            },
          ),
          throwsStateError,
        );
        expect(saves, finalCheck ? 1 : 0);
        expect(await db.select(db.meal).get(), isEmpty);
        expect(
          (await journal.get(operation.claimId, operation.uid))!.mealId,
          isNull,
        );
      },
    );
  }
  test(
    'proof survives restart; clinical effect and receipt commit once even after meal deletion',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clinical-chat-journal-',
      );
      DatabaseImpl open() => DatabaseImpl(
        NativeDatabase(File('${directory.path}/clinical.sqlite')),
      );
      var db = open();
      try {
        var journal = FamilyTreatmentJournal(db);
        final first = await journal.prepare(
          uid: 'child',
          familyId: 'family',
          messageId: 'message',
          installationId: 'phone',
          proof: 'original',
          confirmedAt: 1234,
          actualQuantity: 1.5,
          authorization: (
            epoch: 'epoch',
            accountOffGeneration: 2,
            familyOffGeneration: 3,
          ),
        );
        await db.close();
        db = open();
        journal = FamilyTreatmentJournal(db);
        final restored = await journal.prepare(
          uid: 'child',
          familyId: 'family',
          messageId: 'message',
          installationId: 'phone',
          proof: 'new-unused',
          confirmedAt: 5678,
        );
        expect(restored.proof, first.proof);
        expect(restored.confirmedAt, first.confirmedAt);
        expect(restored.actualQuantity, 1.5);
        expect(restored.authorization, first.authorization);
        var saves = 0;
        Future<int> apply() => journal.apply(
          restored,
          authorized: () async => true,
          elapsedMilliseconds: () => 10,
          deadlineMilliseconds: 10000,
          appliedAt: 1000,
          save: () async {
            saves++;
            await db.customStatement(
              "INSERT INTO meal(name,planned_at,status,purpose) VALUES('test',1000,'confirmed','lowTreatment')",
            );
            return (await db
                    .customSelect('SELECT last_insert_rowid() AS id')
                    .getSingle())
                .read<int>('id');
          },
        );
        final mealId = await apply();
        await db.customStatement('DELETE FROM meal WHERE id=?', [mealId]);
        expect(await apply(), mealId);
        expect(saves, 1);
        await journal.acknowledge(restored);
        expect((await journal.get(first.claimId, 'child'))!.acknowledged, true);
        expect(await journal.get(first.claimId, 'other-child'), isNull);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  for (final revoke in [false, true]) {
    test(
      'lease expiry or revocation rolls back clinical write and journal together: revoke=$revoke',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final journal = FamilyTreatmentJournal(db);
        final operation = await journal.prepare(
          uid: 'child',
          familyId: 'family',
          messageId: 'message',
          installationId: 'phone',
          proof: 'proof',
        );
        var allowed = true, elapsed = 0;
        await expectLater(
          journal.apply(
            operation,
            authorized: () async => allowed,
            elapsedMilliseconds: () => elapsed,
            deadlineMilliseconds: 10000,
            appliedAt: 1000,
            save: () async {
              await db.customStatement(
                "INSERT INTO meal(name,planned_at,status,purpose) VALUES('test',1000,'confirmed','lowTreatment')",
              );
              if (revoke) {
                allowed = false;
              } else {
                elapsed = 10000;
              }
              return 1;
            },
          ),
          throwsStateError,
        );
        expect(await db.select(db.meal).get(), isEmpty);
        expect(
          (await journal.get(operation.claimId, operation.uid))!.mealId,
          isNull,
        );
      },
    );
  }
}
