import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../repositories/low_treatment_review_repository.dart';

final lowTreatmentReviewRepositoryProvider = Provider(
  (ref) => LowTreatmentReviewRepository(ref.watch(databaseProvider)),
);
