import '../event/model/foreground_event.dart';

sealed class RuntimeInput {
  const RuntimeInput();
}

class RuntimeEventInput extends RuntimeInput {
  final ForegroundEvent event;

  const RuntimeEventInput(this.event);
}

class RuntimeSignalInput extends RuntimeInput {
  final String signalKey;

  const RuntimeSignalInput(this.signalKey);
}