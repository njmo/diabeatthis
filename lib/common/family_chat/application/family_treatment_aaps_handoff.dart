import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/low_treatment/data/providers/low_treatment_aaps_provider.dart';
import '../../../features/low_treatment/data/providers/low_treatment_handoff_provider.dart';
import '../../../features/low_treatment/domain/models/low_treatment_handoff_pending.dart';
import '../../../features/low_treatment/presentation/controllers/low_treatment_aaps_controller.dart';
import '../../l10n/language.dart';
import 'confirm_family_treatment.dart';

final familyTreatmentAapsHandoffProvider = Provider<FamilyTreatmentAapsHandoff>(
  (ref) => FamilyTreatmentAapsHandoff(
    ref.watch(lowTreatmentAapsControllerProvider),
    ref.watch(lowTreatmentHandoffRepositoryProvider).loadPending,
  ),
);

class FamilyTreatmentAapsHandoff {
  const FamilyTreatmentAapsHandoff(this._aaps, this._loadPending);

  final LowTreatmentAapsController _aaps;
  final Future<List<LowTreatmentHandoffPending>> Function() _loadPending;

  Future<LowTreatmentHandoffPending?> pendingFor(int mealId) async {
    if (await _aaps.usesNightscout(mealId)) return null;
    return (await _loadPending())
        .where((item) => item.mealId == mealId && item.matchedTreatAt == null)
        .firstOrNull;
  }

  // False leaves the intent queued until the app can act on it.
  Future<bool> open({
    required ConfirmFamilyTreatment executor,
    required String messageId,
    required Future<bool> Function() isCurrent,
    required Future<bool> Function(LowTreatmentHandoffPending) confirm,
  }) async {
    final mealId = (await executor.lookup(messageId))?.mealId;
    if (mealId == null) return true;
    final pending = await pendingFor(mealId);
    if (pending == null) return true;
    if (!await isCurrent()) return false;
    if (await confirm(pending) &&
        await pendingFor(mealId) != null &&
        await isCurrent()) {
      await _aaps.open(mealId, lang);
    }
    return true;
  }
}
