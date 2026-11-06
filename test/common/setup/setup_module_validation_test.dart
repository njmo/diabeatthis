import 'package:diabeatthis/common/setup/domain/collect_setup_configuration_fields_use_case.dart';
import 'package:diabeatthis/common/setup/domain/get_available_setup_features_use_case.dart';
import 'package:diabeatthis/common/setup/domain/setup_configuration_field.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature_option.dart';
import 'package:diabeatthis/common/setup/domain/validate_setup_module_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final input in [('not-a-url', 'token'), ('https://example.com', '  ')]) {
    test(
      'invalid required connection values $input do not invoke the adapter',
      () async {
        var calls = 0;
        final valid = await const ValidateSetupModuleUseCase()(
          requiredFields: SetupConfigurationField.values,
          values: {
            SetupConfigurationField.nightscoutUrl: input.$1,
            SetupConfigurationField.nightscoutToken: input.$2,
          },
          validateNightscout: true,
          requiresWrite: true,
          checkConnection: (_, _, _) async {
            calls++;
            return true;
          },
        );
        expect(valid, isFalse);
        expect(calls, 0);
      },
    );
  }
  test(
    'data-source URL dependencies are conditional and merge with monitor options',
    () {
      final features = GetAvailableSetupFeaturesUseCase.catalog.where(
        (feature) => {
          SetupFeatureId.dataAndMeals,
          SetupFeatureId.lowTreatment,
        }.contains(feature.id),
      );
      const collect = CollectSetupConfigurationFieldsUseCase();
      expect(collect(features), isEmpty);
      final readOnly = collect(features, usesCloudData: true);
      expect(readOnly, {
        SetupConfigurationField.nightscoutUrl: {SetupFeatureId.dataAndMeals},
      });
      final writable = collect(
        features,
        usesCloudData: true,
        enabledOptions: {SetupFeatureOptionId.lowTreatmentCarbohydrateUpload},
      );
      expect(writable[SetupConfigurationField.nightscoutUrl], {
        SetupFeatureId.dataAndMeals,
        SetupFeatureId.lowTreatment,
      });
      expect(writable[SetupConfigurationField.nightscoutToken], {
        SetupFeatureId.lowTreatment,
      });
    },
  );
}
