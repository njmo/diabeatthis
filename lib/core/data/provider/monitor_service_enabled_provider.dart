import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../common/app_mode/application_device_mode.dart';

part 'monitor_service_enabled_provider.g.dart';

@riverpod
bool monitorServiceEnabled(Ref ref) =>
    ref.watch(applicationDeviceModeProvider).asData?.value !=
    ApplicationDeviceMode.caregiver;
