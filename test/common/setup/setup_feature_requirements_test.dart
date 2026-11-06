import 'package:diabeatthis/common/setup/domain/collect_setup_requirements_use_case.dart';
import 'package:diabeatthis/common/setup/domain/get_available_setup_features_use_case.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'caregiver catalog excludes patient monitors and keeps family features',
    () {
      final features = const GetAvailableSetupFeaturesUseCase()(
        const SetupPersonConfiguration(mode: SetupDeviceMode.caregiver),
      );
      expect(
        features.map((feature) => feature.id),
        containsAll([SetupFeatureId.familyChat, SetupFeatureId.childOverview]),
      );
      expect(
        features.map((feature) => feature.id),
        isNot(contains(SetupFeatureId.mealMonitor)),
      );
      expect(
        features.map((feature) => feature.id),
        isNot(contains(SetupFeatureId.activityMonitor)),
      );
    },
  );

  test(
    'requirements are deduplicated while preserving all dependent features',
    () {
      final features =
          const GetAvailableSetupFeaturesUseCase()(
            const SetupPersonConfiguration(mode: SetupDeviceMode.patient),
          ).where(
            (feature) => {
              SetupFeatureId.mealMonitor,
              SetupFeatureId.activityMonitor,
              SetupFeatureId.familyChat,
            }.contains(feature.id),
          );
      final requirements = const CollectSetupRequirementsUseCase()(features);
      expect(requirements[SetupRequirement.notifications], {
        SetupFeatureId.mealMonitor,
        SetupFeatureId.activityMonitor,
        SetupFeatureId.familyChat,
      });
      expect(requirements[SetupRequirement.backgroundExecution], {
        SetupFeatureId.mealMonitor,
        SetupFeatureId.activityMonitor,
      });
      expect(requirements.containsKey(SetupRequirement.camera), isFalse);
      expect(
        () => requirements[SetupRequirement.notifications]!.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'photo configuration needs camera and AI without enabling AI assistance',
    () {
      final photo = GetAvailableSetupFeaturesUseCase.catalog.singleWhere(
        (feature) => feature.id == SetupFeatureId.mealPhoto,
      );
      final requirements = const CollectSetupRequirementsUseCase()([photo]);
      expect(
        requirements.keys,
        containsAll([
          SetupRequirement.camera,
          SetupRequirement.aiConfiguration,
          SetupRequirement.internet,
        ]),
      );
    },
  );
}
