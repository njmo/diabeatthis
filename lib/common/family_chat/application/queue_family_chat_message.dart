import 'dart:math';

import '../data/family_chat_database.dart';

/// Records a send gesture and removes only the submitted composer revision.
class QueueFamilyChatMessage {
  const QueueFamilyChatMessage(this.db);

  final FamilyChatDatabase db;

  Future<bool?> call({
    required String uid,
    required String scope,
    required String target,
    required String expectedVersion,
    required String? expectedStamp,
    int expectedHistoryGeneration = 0,
    required bool Function() allowed,
    required bool preferSigned,
    required bool allowUnsigned,
    required Map<String, dynamic> payload,
    required int accountOffGeneration,
    required int familyOffGeneration,
    required int Function() now,
    required bool Function() clearSubmittedDraft,
    void Function(String id)? onQueued,
  }) async {
    String? queuedId;
    final signed = await db.withComposerQueueAdmission<bool?>(
      uid: uid,
      scope: scope,
      expectedVersion: expectedVersion,
      expectedStamp: expectedStamp,
      expectedHistoryGeneration: expectedHistoryGeneration,
      allowed: allowed,
      action: () async {
        queuedId = preferSigned
            ? await db.enqueue(scope, target, payload, now())
            : null;
        final signed = queuedId != null;
        if (!signed) {
          if (!allowUnsigned) return null;
          final id = 'local-${now()}-${Random.secure().nextInt(1 << 32)}';
          final queued = await db.enqueueUnsignedComposerMessage(
            scope,
            id,
            target,
            {
              ...payload,
              '_admission': {
                'accountOffGeneration': accountOffGeneration,
                'familyOffGeneration': familyOffGeneration,
              },
            },
            now(),
          );
          if (queued == null) return null;
          queuedId = id;
        }
        if (clearSubmittedDraft()) {
          await db.saveDraft(scope, target, '', serverNow: now());
        }
        return signed;
      },
    );
    if (signed != null && queuedId != null) onQueued?.call(queuedId!);
    return signed;
  }
}
