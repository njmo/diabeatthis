import 'package:diabeatthis/common/app_mode/application_device_mode.dart';

/// Patient-write tests explicitly authorize the local repository.
final patientApplicationModeOverride = applicationDeviceModeProvider
    .overrideWith((_) async => ApplicationDeviceMode.patient);
