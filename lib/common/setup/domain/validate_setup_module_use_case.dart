import 'setup_configuration_field.dart';
import 'validate_setup_configuration_use_case.dart';

enum SetupNightscoutVerification {
  readWriteVerified,
  readVerified,
  tokenRequired,
  invalidToken,
  writeAccessMissing,
  unavailable,
  invalidUrl,
  previewOnly;

  bool get isSuccess =>
      this == readWriteVerified || this == readVerified || this == previewOnly;
  bool isAcceptable({required bool requiresWrite}) => requiresWrite
      ? (this == readWriteVerified || this == previewOnly)
      : isSuccess;
}

/// The preview supplies a simulated check; a real adapter can verify write access.
typedef SetupConnectionValidator =
    Future<SetupNightscoutVerification> Function(
      String url,
      String token,
      bool requiresWrite,
    );

class ValidateSetupModuleUseCase {
  const ValidateSetupModuleUseCase();

  Future<bool> call({
    required Iterable<SetupConfigurationField> requiredFields,
    required Map<SetupConfigurationField, String> values,
    required bool validateNightscout,
    required bool requiresWrite,
    SetupConnectionValidator? checkConnection,
  }) async {
    if (const ValidateSetupConfigurationUseCase()(
      requiredFields: requiredFields,
      values: values,
    ).isNotEmpty) {
      return false;
    }
    if (!validateNightscout) return true;
    final url = values[SetupConfigurationField.nightscoutUrl]?.trim() ?? '';
    final token = values[SetupConfigurationField.nightscoutToken]?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return false;
    }
    // No network operation is performed by the default preview validator.
    return checkConnection == null
        ? true
        : (await checkConnection(
            url,
            token,
            requiresWrite,
          )).isAcceptable(requiresWrite: requiresWrite);
  }
}
