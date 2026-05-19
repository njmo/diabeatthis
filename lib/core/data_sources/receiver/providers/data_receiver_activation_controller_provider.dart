import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../aaps/providers/aaps_receiver_controller_provider.dart';
import '../../xdrip/providers/xdrip_receiver_controller_provider.dart';
import '../data_receiver_activation_controller.dart';

part 'data_receiver_activation_controller_provider.g.dart';

@riverpod
DataReceiverActivationController dataReceiverActivationController(Ref ref) {
  return DataReceiverActivationController(
    xdripReceiverController: ref.watch(xdripReceiverControllerProvider),
    aapsReceiverController: ref.watch(aapsReceiverControllerProvider),
  );
}
