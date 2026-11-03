import 'package:diabeatthis/core/data_sources/aaps/aaps_receiver_controller.dart';
import 'package:diabeatthis/core/data_sources/receiver/data_receiver_controller.dart';
import 'package:diabeatthis/core/data_sources/xdrip/xdrip_receiver_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  for (final receiver
      in <({String channel, DataReceiverController controller})>[
        (
          channel: 'pl.diabeatthis.app/aaps_receiver',
          controller: const AapsReceiverController(),
        ),
        (
          channel: 'pl.diabeatthis.app/xdrip_receiver',
          controller: const XdripReceiverController(),
        ),
      ]) {
    test(
      'receiver invokes only its own activation channel: ${receiver.channel}',
      () async {
        final calls = <String>[];
        final channel = MethodChannel(receiver.channel);
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          calls.add(call.method);
          return null;
        });
        addTearDown(
          () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await receiver.controller.setEnabled();
        await receiver.controller.setDisabled();
        expect(calls, ['setEnabled', 'setDisabled']);
      },
    );
    test(
      'receiver platform errors remain failures: ${receiver.channel}',
      () async {
        final channel = MethodChannel(receiver.channel);
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'permission_denied'),
        );
        addTearDown(
          () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await expectLater(
          receiver.controller.setEnabled(),
          throwsA(isA<PlatformException>()),
        );
        await expectLater(
          receiver.controller.setDisabled(),
          throwsA(isA<PlatformException>()),
        );
      },
    );
  }
}
