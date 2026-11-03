import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_review_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedLowTreatmentReviewRepository extends Fake
    implements LowTreatmentReviewRepository {
  final ScriptedRead<void> writes;
  ScriptedLowTreatmentReviewRepository(this.writes);

  @override
  Future<void> save(Treat event, {int? mealId, bool dismissed = false}) =>
      writes(['save', event, mealId, dismissed]);

  @override
  Future<void> reset(DateTime occurredAt) => writes(['reset', occurredAt]);
}
