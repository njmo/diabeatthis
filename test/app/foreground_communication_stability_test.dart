import 'package:diabeatthis/app/lifecycle/app_foreground_bridge.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'resuming does not replace the receive port or lose pending readiness',
    () async {
      final bridge = AppForegroundBridge();
      final messages = <Object>[];
      bridge.attach(messages.add);
      addTearDown(() async {
        bridge.detach(messages.add);
        await FlutterForegroundTask.streamSubscription?.cancel();
        FlutterForegroundTask.receivePort?.close();
      });
      bridge.reInitCommunicationPort();
      final port = FlutterForegroundTask.receivePort!;
      port.sendPort.send('ready');
      bridge.reInitCommunicationPort();
      expect(FlutterForegroundTask.receivePort, same(port));
      await Future<void>.delayed(Duration.zero);
      expect(messages, ['ready']);
    },
  );
}
