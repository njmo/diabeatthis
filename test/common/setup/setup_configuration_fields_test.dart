import 'package:diabeatthis/common/setup/domain/collect_setup_configuration_fields_use_case.dart';
import 'package:diabeatthis/common/setup/domain/get_available_setup_features_use_case.dart';
import 'package:diabeatthis/common/setup/domain/setup_configuration_field.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature_option.dart';
import 'package:diabeatthis/common/setup/domain/validate_setup_configuration_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'both monitor upload options require URL and token with immutable provenance',
    () {
      final uploads = GetAvailableSetupFeaturesUseCase.catalog.where(
        (feature) => {
          SetupFeatureId.lowTreatment,
          SetupFeatureId.activityMonitor,
        }.contains(feature.id),
      );
      final fields = const CollectSetupConfigurationFieldsUseCase()(
        uploads,
        enabledOptions: SetupFeatureOptionId.values.toSet(),
      );
      expect(fields.keys, containsAll(SetupConfigurationField.values));
      for (final field in fields.values) {
        expect(field, {
          SetupFeatureId.lowTreatment,
          SetupFeatureId.activityMonitor,
        });
        expect(() => field.clear(), throwsUnsupportedError);
      }
      expect(() => fields.clear(), throwsUnsupportedError);
      expect(const CollectSetupConfigurationFieldsUseCase()([]), isEmpty);
    },
  );
  test(
    'required-field validation trims input and ignores unrequired fields',
    () {
      const validate = ValidateSetupConfigurationUseCase();
      expect(
        validate(
          requiredFields: SetupConfigurationField.values,
          values: {
            SetupConfigurationField.nightscoutUrl: ' https://example.com ',
            SetupConfigurationField.nightscoutToken: '  ',
          },
        ),
        {SetupConfigurationField.nightscoutToken},
      );
      expect(
        validate(requiredFields: SetupConfigurationField.values, values: {}),
        SetupConfigurationField.values.toSet(),
      );
      expect(validate(requiredFields: [], values: {}), isEmpty);
    },
  );
  test(
    'local monitors do not acquire upload credentials or caregiver-only monitor features',
    () {
      final monitor = GetAvailableSetupFeaturesUseCase.catalog.singleWhere(
        (feature) => feature.id == SetupFeatureId.mealMonitor,
      );
      expect(monitor.requiredConfiguration, isEmpty);
      final caregiver = const GetAvailableSetupFeaturesUseCase()(
        const SetupPersonConfiguration(mode: SetupDeviceMode.caregiver),
      );
      expect(
        caregiver.any(
          (feature) =>
              feature.id == SetupFeatureId.lowTreatment ||
              feature.id == SetupFeatureId.activityMonitor,
        ),
        isFalse,
      );
    },
  );
}
