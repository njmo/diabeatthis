import '../../../../core/data_sources/config/data_source_config.dart';

class NightscoutSettingsDraft {
  const NightscoutSettingsDraft({
    required this.url,
    required this.token,
    required this.tempTargetsEnabled,
    required this.childName,
    this.dataSourceConfig,
  });

  final String url;
  final String token;
  final bool tempTargetsEnabled;
  final String childName;
  final DataSourceConfig? dataSourceConfig;
}
