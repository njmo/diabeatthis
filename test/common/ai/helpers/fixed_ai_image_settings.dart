import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';

class FixedAiImageSettings extends AiSettingsController {
  FixedAiImageSettings(this.configuration);

  final AiConfiguration configuration;

  @override
  Future<AiConfiguration> build() async => configuration;
}
