import 'dart:collection';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final String? error;
  final String? stackTrace;

  const LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String toLine() {
    final b = StringBuffer()
      ..write('[${time.toIso8601String()}] ')
      ..write('[${level.name}] ')
      ..write('[$tag] ')
      ..write(message);

    if (error != null) {
      b.write(' error=$error');
    }

    return b.toString();
  }
}

class LogRuntimeConfig {
  LogRuntimeConfig._();

  static bool bufferEnabled = false;
  static int maxEntries = 500;
  static bool isUnitTestEnv = false;

  static void configure({required bool enableBuffer, int? capacity, bool? isUnitTest}) {
    bufferEnabled = enableBuffer;
    if(isUnitTest != null) isUnitTestEnv = isUnitTest;
    if (capacity != null) {
      maxEntries = capacity;
      LogBuffer.instance.resize(capacity);
    }
  }
}

class LogBuffer {
  LogBuffer._();
  static final instance = LogBuffer._();

  final ListQueue<LogEntry> _queue = ListQueue<LogEntry>();
  int _capacity = 500;

  void resize(int capacity) {
    _capacity = capacity;
    while (_queue.length > _capacity) {
      _queue.removeFirst();
    }
  }

  void add(LogEntry entry) {
    if (_queue.length >= _capacity) {
      _queue.removeFirst();
    }
    _queue.addLast(entry);
  }

  List<LogEntry> snapshot() => List.unmodifiable(_queue);

  void clear() => _queue.clear();
}

class Log {
  static void d(String tag, String msg) {
    _log(LogLevel.debug, tag, msg);
  }

  static void i(String tag, String msg) {
    _log(LogLevel.info, tag, msg);
  }

  static void w(String tag, String msg) {
    _log(LogLevel.warning, tag, msg);
  }

  static void e(
    String tag,
    String msg, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.error, tag, msg, error: error, stackTrace: stackTrace);
  }

  static void _log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      time: clock.now(),
      level: level,
      tag: tag,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    // 1. Debug logging do DevTools / logcat
    assert(() {

      if (LogRuntimeConfig.isUnitTestEnv) print(entry.toLine());
      else {
        dev.log(
          entry.toLine(),
          name: tag,
          level: _toDevLevel(level),
          error: error,
          stackTrace: stackTrace,
        );
      }

      return true;
    }());

    // 2. Produkcyjny bufor w RAM
    if (LogRuntimeConfig.bufferEnabled) {
      LogBuffer.instance.add(entry);
    }
  }

  static int _toDevLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  static List<LogEntry> get bufferedLogs => LogBuffer.instance.snapshot();

  static void clearBuffer() => LogBuffer.instance.clear();
}

mixin Logging {
  String get logTag => runtimeType.toString();

  void logD(String message) => Log.d(logTag, message);
  void logI(String message) => Log.i(logTag, message);
  void logW(String message) => Log.w(logTag, message);

  void logE(String message, {Object? error, StackTrace? stackTrace}) {
    Log.e(logTag, message, error: error, stackTrace: stackTrace);
  }
}

class LogFileWriter {
  static Future<File> writeLogs(List<LogEntry> logs, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    final sink = file.openWrite();

    for (final log in logs) {
      sink.writeln(log.toLine());
    }

    await sink.flush();
    await sink.close();

    return file;
  }
}
