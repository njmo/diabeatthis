import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drift/database_impl.dart' show ActivityScheduleData;
import 'activity_catalog_repository.dart';

abstract interface class ActivityScheduleActivationRepository {
  Future<void> setScheduleEnabled(ActivityScheduleData rule, bool enabled);
}

final activityScheduleActivationRepositoryProvider =
    Provider<ActivityScheduleActivationRepository>((ref) {
      final repository = ref.watch(activityCatalogRepositoryProvider);
      if (repository is! ActivityScheduleActivationRepository) {
        throw StateError('Schedule activation unavailable');
      }
      return repository as ActivityScheduleActivationRepository;
    }, dependencies: [activityCatalogRepositoryProvider]);
