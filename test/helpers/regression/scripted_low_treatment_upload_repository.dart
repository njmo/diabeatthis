import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_upload_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedLowTreatmentUploadRepository extends Fake
    implements LowTreatmentUploadRepository {
  ScriptedRead<bool>? matched;
  @override
  Future<bool> hasMatchedTreatment(int mealId) {
    final response = matched;
    if (response == null) throw StateError('Unscripted treatment receipt read');
    return response([mealId]);
  }

  final queued = <Map<String, Object?>>[];
  final updates = <Map<String, Object?>>[];
  final links = <({int mealId, String externalId})>[];
  List<LowTreatmentUploadData> pendingRows = [];
  final pendingReads = <DateTime>[];
  @override
  Future<void> enqueue({
    required int mealId,
    required String identifier,
    required String sourceKey,
    required DateTime eatenAt,
    required double carbs,
  }) async => queued.add({
    'mealId': mealId,
    'identifier': identifier,
    'sourceKey': sourceKey,
    'eatenAt': eatenAt,
    'carbs': carbs,
  });
  @override
  Future<List<LowTreatmentUploadData>> pending(DateTime now) async {
    pendingReads.add(now);
    return pendingRows;
  }

  @override
  Future<void> update(
    int mealId,
    String state, {
    bool? attempted,
    String? externalId,
    DateTime? nextAttempt,
  }) async => updates.add({
    'mealId': mealId,
    'state': state,
    'attempted': attempted,
    'externalId': externalId,
    'nextAttempt': nextAttempt,
  });
  @override
  Future<void> link(LowTreatmentUploadData upload, String externalId) async =>
      links.add((mealId: upload.mealId, externalId: externalId));
}
