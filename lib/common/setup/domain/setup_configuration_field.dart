import 'setup_feature.dart';

/// Typed configuration dependencies, separate from system permissions.
enum SetupConfigurationField {
  nightscoutUrl(SetupModule.nightscout),
  nightscoutToken(SetupModule.nightscout);

  const SetupConfigurationField(this.module);
  final SetupModule module;
}
