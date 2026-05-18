import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../xdrip_receiver_controller.dart';

part 'xdrip_receiver_controller_provider.g.dart';

@riverpod
XdripReceiverController xdripReceiverController(Ref ref) {
  return const XdripReceiverController();
}
