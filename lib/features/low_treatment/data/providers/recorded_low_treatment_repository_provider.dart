import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../repositories/recorded_low_treatment_repository.dart';

final recordedLowTreatmentRepositoryProvider =
    Provider<RecordedLowTreatmentRepository>(
      (ref) => RecordedLowTreatmentRepository(ref.read(databaseProvider)),
    );
