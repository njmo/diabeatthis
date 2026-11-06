import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SetupAiSettingsTestController extends AiSettingsController {
  SetupAiSettingsTestController({this.configuration = const AiConfiguration()});
  AiConfiguration configuration;
  int saves = 0;
  int tests = 0;
  @override
  Future<void> testConnection(
    AiConfiguration configuration, {
    String? apiKey,
  }) async {
    tests++;
  }

  @override
  Future<AiConfiguration> build() async => configuration;
  @override
  Future<bool> hasApiKey() async => false;
  @override
  Future<bool> isChatGptConnected() async => false;
  @override
  Future<void> save(AiConfiguration value, {String? apiKey}) async {
    saves++;
    configuration = value;
    state = AsyncData(value);
  }
}
