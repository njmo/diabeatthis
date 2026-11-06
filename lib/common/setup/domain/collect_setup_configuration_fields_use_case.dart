import 'setup_configuration_field.dart';
import 'setup_feature.dart';
import 'setup_feature_option.dart';

/// Preserves which features require each field, for validation and explanations.
class CollectSetupConfigurationFieldsUseCase {
  const CollectSetupConfigurationFieldsUseCase();

  Map<SetupConfigurationField, Set<SetupFeatureId>> call(
    Iterable<SetupFeature> features, {
    Set<SetupFeatureOptionId> enabledOptions = const {},
  }) {
    final result = <SetupConfigurationField, Set<SetupFeatureId>>{};
    for (final feature in features) {
      final required = {
        ...feature.requiredConfiguration,
        for (final option in feature.options.where(
          (option) => enabledOptions.contains(option.id),
        ))
          ...option.requiredConfiguration,
      };
      for (final field in required) {
        result.putIfAbsent(field, () => {}).add(feature.id);
      }
    }
    return Map.unmodifiable(
      result.map(
        (key, value) => MapEntry(key, Set<SetupFeatureId>.unmodifiable(value)),
      ),
    );
  }
}
