import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/history/bolus_wizard_grouping.dart';
import '../../core/data_sources/providers/source_repository_providers.dart';
import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/treatment_base.dart';

/// Reads the configured source, including cloud history without a local mirror.
final mealBolusDeliveryHistoryProvider =
    Provider<Future<List<Treatment>> Function(BolusWizard)>((ref) {
      return (wizard) async {
        try {
          final repository = await ref
              .read(treatmentsHistoryRepositoryProvider.future)
              .timeout(const Duration(seconds: 2));
          final margin =
              BolusWizardGrouping.carbSubmissionWindow +
              BolusWizardGrouping.deliveryClockTolerance;
          final now = clock.now();
          final latest = now.isAfter(wizard.createdAt) ? now : wizard.createdAt;
          return await repository
              .fetchTreatmentsBetween(
                wizard.createdAt.subtract(margin),
                latest.add(margin),
              )
              .timeout(const Duration(seconds: 2));
        } catch (_) {
          // Missing/offline history leaves the submission pending. Live
          // confirmation and later source refreshes can still complete it.
          return const [];
        }
      };
    });
