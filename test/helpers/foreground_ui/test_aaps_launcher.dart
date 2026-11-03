import 'package:diabeatthis/common/platform/aaps_launcher.dart';

class TestAapsLauncher extends AapsLauncher {
  const TestAapsLauncher();

  @override
  Future<AapsLaunchResult> openAaps() async => AapsLaunchResult.opened;
}
