import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../common/temporary_targets/owned_temp_target.dart';
import '../../../../common/temporary_targets/temp_target_proposal.dart';
import '../nightscout_storage_keys.dart';
import 'temp_target_operation_repository.dart';

/// Imports earlier runtime records before removing their preference keys.
class TempTargetLegacyMigration {
  const TempTargetLegacyMigration(this.operations);

  final TempTargetOperationRepository operations;

  Future<void> migrate(SharedPreferences preferences) async {
    final ownedJson = preferences.getString(nightscoutOwnedTempTargetKey);
    if (ownedJson != null) {
      final owned = OwnedTempTarget.fromJson(
        jsonDecode(ownedJson) as Map<String, dynamic>,
      );
      await operations.importConfirmedOwned(owned);
      final stopped = preferences.getString('temp_target_stop_attempted');
      if (stopped == owned.startedAt.toIso8601String()) {
        // The old record did not retain the exact cancellation time. Preserve
        // its uncertainty instead of risking another cancellation.
        final stop = await operations.createStop(
          requestId: 'legacy-stop-${owned.startedAt.microsecondsSinceEpoch}',
          owned: owned,
          stoppedAt: owned.startedAt.add(const Duration(seconds: 1)),
        );
        if (await operations.claimStop(stop.requestId)) {
          await operations.markUnknownResult(stop.requestId);
        }
      }
      await preferences.remove(nightscoutOwnedTempTargetKey);
      await preferences.remove('temp_target_stop_attempted');
    }
    for (final key
        in preferences
            .getKeys()
            .where((key) => key.startsWith('temp_target_offer_'))
            .toList()) {
      final value = preferences.getString(key);
      if (value == null) continue;
      final proposal = TempTargetProposal.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
      await operations.createOffer(proposal);
      if (preferences.containsKey('temp_target_used_${proposal.id}')) {
        // Old consumed offers cannot authorize another write after migration.
        await operations.decline(proposal.id);
      }
      await preferences.remove(key);
      await preferences.remove('temp_target_used_${proposal.id}');
    }
  }
}
