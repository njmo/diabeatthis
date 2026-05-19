import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../aaps_receiver_controller.dart';

part 'aaps_receiver_controller_provider.g.dart';

@riverpod
AapsReceiverController aapsReceiverController(Ref ref) {
  return const AapsReceiverController();
}
