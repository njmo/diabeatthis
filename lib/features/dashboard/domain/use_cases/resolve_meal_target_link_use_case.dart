import '../../../../common/events/data/notification/temp_target_type.dart';
import '../../../../common/temporary_targets/temp_target_operation.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../common/temporary_targets/temp_target_identity.dart';

/// Manual confirmation wins; external proximity never establishes identity.
class ResolveMealTargetLinkUseCase {
  const ResolveMealTargetLinkUseCase();

  int? call({
    required String source,
    required TemporaryTarget target,
    required int? manualMealId,
    required List<TempTargetOperation> operations,
  }) {
    if (source.isEmpty) return null;
    if (manualMealId != null) return manualMealId;
    for (final operation in operations) {
      final owned = operation.confirmedTarget;
      if (operation.kind == TempTargetOperationKind.start &&
          owned != null &&
          owned.source == source &&
          owned.targetType == TempTargetType.meal &&
          TempTargetIdentity.matches(owned, target)) {
        return owned.entityId;
      }
    }
    return null;
  }
}
