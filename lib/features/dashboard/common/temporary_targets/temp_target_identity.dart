import '../../../../common/temporary_targets/owned_temp_target.dart';
import '../../../../core/domain/model/temporary_target.dart';

/// Exact identity for display links; time proximity alone is never a link.
class TempTargetIdentity {
  const TempTargetIdentity._();

  static String key(String source, TemporaryTarget target) =>
      Uri.encodeComponent(
        '$source|${target.nightscoutId ?? ''}|'
        '${target.createdAt.millisecondsSinceEpoch}|${target.duration}|'
        '${target.targetBottom}|${target.targetTop}',
      );

  static bool matches(OwnedTempTarget owned, TemporaryTarget target) {
    if (owned.nightscoutId != null && target.nightscoutId != null) {
      return owned.nightscoutId == target.nightscoutId;
    }
    return owned.startedAt.isAtSameMomentAs(target.createdAt) &&
        owned.durationMinutes == target.duration &&
        owned.target == target.targetBottom &&
        owned.target == target.targetTop;
  }
}
