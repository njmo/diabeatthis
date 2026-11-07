import 'dart:convert';

import '../../core/drift/family_sync/family_mirror_outbox.dart';
import '../backend/authenticated_callable_transport.dart';
import 'family_mirror_record.dart';
import 'register_family_mirror.dart';

class PublishFamilyMirrorUseCase {
  const PublishFamilyMirrorUseCase({
    required this.outbox,
    required this.transport,
    required this.currentUid,
    this.canSend,
  });
  final FamilyMirrorOutbox outbox;
  final AuthenticatedCallableTransport transport;
  final String? Function() currentUid;
  final Future<bool> Function()? canSend;
  Future<bool> permitted() async => canSend == null || await canSend!();
  bool valid(FamilyMirrorRecord record) {
    final values = record.payload?.values ?? const <Object?>[];
    return utf8.encode(jsonEncode(record.payload)).length <= 65536 &&
        values.every(
          (value) =>
              value == null ||
              value is String && value.length <= 32000 ||
              value is num && value.isFinite && value.abs() <= 9007199254740991,
        );
  }

  Future<int> call() async {
    final uid = currentUid();
    if (uid == null) throw const CallableFailure('unauthenticated');
    if (!await permitted()) return 0;
    // No callable, rate-limit write or identity loading for an empty queue.
    if ((await outbox.pending(limit: 1)).isEmpty) return 0;
    // A newly allocated record must be locked to its pending caregiver plan
    // before any independent mirror worker can make it visible to others.
    final unbound = await outbox.db
        .customSelect(
          "SELECT operation_id FROM family_plan_journal WHERE outcome='applied' AND acknowledged=0 AND result_bound=0 LIMIT 1",
        )
        .get();
    if (unbound.isNotEmpty) return 0;
    final source = await outbox.sourceForOwner(uid);
    await registerFamilyMirror(
      transport: transport,
      source: source,
      uid: uid,
      permitted: permitted,
    );
    if (currentUid() != uid) throw const CallableFailure('unauthenticated');
    await outbox.bindOwner(uid);
    var count = 0;
    for (var batch = 0; batch < 10; batch++) {
      if (currentUid() != uid) throw const CallableFailure('unauthenticated');
      if (!await permitted()) break;
      final pending = await outbox.publishable();
      if (pending.isEmpty) break;
      final records = <FamilyMirrorRecord>[];
      for (final record in pending) {
        if (!valid(record)) {
          await outbox.reject(record);
          continue;
        }
        final bytes = utf8
            .encode(
              jsonEncode({
                'data': {
                  'sourceId': source,
                  'records': [
                    ...records,
                    record,
                  ].map((row) => row.toJson()).toList(),
                },
              }),
            )
            .length;
        if (bytes > 240000) break;
        records.add(record);
      }
      if (records.isEmpty) continue;
      final receipt = await transport.call(
        'publishFamilyMirror',
        {
          'sourceId': source,
          'records': records.map((record) => record.toJson()).toList(),
        },
        expectedUid: uid,
        allowRequest: permitted,
      );
      final acknowledgements = receipt['acknowledged'] as List?;
      if (receipt['sourceId'] != source ||
          acknowledgements == null ||
          acknowledgements.length != records.length ||
          currentUid() != uid) {
        throw const CallableFailure('invalid-response');
      }
      final expected = {
        for (final record in records)
          '${record.kind}/${record.id}/${record.revision}',
      };
      final actual = acknowledgements.map((raw) {
        final entry = raw as Map;
        return '${entry['kind']}/${entry['id']}/${entry['revision']}';
      }).toSet();
      if (actual.length != expected.length || !actual.containsAll(expected)) {
        throw const CallableFailure('invalid-response');
      }
      await outbox.acknowledge(uid, source, records);
      count += records.length;
    }
    return count;
  }
}
