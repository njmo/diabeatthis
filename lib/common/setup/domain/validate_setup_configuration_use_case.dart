import 'setup_configuration_field.dart';

class ValidateSetupConfigurationUseCase {
  const ValidateSetupConfigurationUseCase();

  Set<SetupConfigurationField> call({
    required Iterable<SetupConfigurationField> requiredFields,
    required Map<SetupConfigurationField, String> values,
  }) => Set.unmodifiable(
    requiredFields.where((field) => values[field]?.trim().isEmpty ?? true),
  );
}
