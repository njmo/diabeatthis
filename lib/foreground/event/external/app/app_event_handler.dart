import 'package:share_plus/share_plus.dart';

import '../../../../core/logger/logger.dart';
import '../../../task/base/runtime_context.dart';
import 'app_event.dart';

class AppEventHandler {
  AppEventHandler();

  void handle(AppEvent event, RuntimeContext runtimeContext) {
    event.when(
      appLifecycleState: (final data) {
        runtimeContext.emitEvent(data);
      },
      dumpLogs: (final data) async {
        final file = await LogFileWriter.writeLogs(Log.bufferedLogs, data.name);
        SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)]),
        );
      },
    );
  }
}
