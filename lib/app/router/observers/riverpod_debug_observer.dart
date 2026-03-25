import 'dart:collection';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/logger.dart';

typedef ValueFormatter = String Function(Object? value);

final class RiverpodDebugObserver extends ProviderObserver with Logging {
  RiverpodDebugObserver({
    this.env = 'router',
    this.includeNames,
    this.excludeNames,
    this.prettyAsyncValue = true,
    this.maxValueLength = 400,
    this.trackDurations = true,
    this.format = LogFormat.jsonl, // ← JSON lines domyślnie
    this.valueFormatter,
  });

  /// Filtry po nazwie providera (exact string lub RegExp)
  final List<Pattern>? includeNames;
  final List<Pattern>? excludeNames;

  final bool prettyAsyncValue;
  final int maxValueLength;
  final bool trackDurations;
  String env;

  final LogFormat format;
  final ValueFormatter? valueFormatter;

  final _lastChange = HashMap<Object, DateTime>();

  // -------- helpers

  String _providerName(ProviderObserverContext ctx) =>
      ctx.provider.name ?? ctx.provider.runtimeType.toString();

  bool _matches(List<Pattern>? patterns, String name) {
    if (patterns == null || patterns.isEmpty) return false;
    for (final p in patterns) {
      if (p is RegExp) {
        if (p.hasMatch(name)) return true;
      } else {
        if (name == p.toString()) return true;
      }
    }
    return false;
  }

  bool _shouldLog(ProviderObserverContext ctx) {
    final name = _providerName(ctx);
    if (excludeNames != null && _matches(excludeNames, name)) return false;
    if (includeNames == null || includeNames!.isEmpty) return true;
    return _matches(includeNames, name);
  }

  String _short(String s) =>
      s.length <= maxValueLength ? s : '${s.substring(0, maxValueLength)}…(${s.length - maxValueLength} more)';

  String _fmtValue(Object? v) {
    if (valueFormatter != null) return _short(valueFormatter!(v));

    if (prettyAsyncValue && v is AsyncValue) {
      return v.when(
        data: (d) => 'AsyncData(${_short('$d')})',
        loading: () => 'AsyncLoading()',
        error: (e, _) => 'AsyncError(${_short('$e')})',
      );
    }
    // Zamień znaki nowej linii na „⏎”, żeby utrzymać 1 linię
    final s = '$v'.replaceAll('\n', r'\n');
    return _short(s);
  }

  int? _deltaMs(ProviderObserverContext ctx) {
    if (!trackDurations) return null;
    final now = clock.now();
    final prev = _lastChange[ctx.provider];
    _lastChange[ctx.provider] = now;
    if (prev == null) return null;
    return now.difference(prev).inMilliseconds;
  }

  // -------- emitters

  void _logAdd(ProviderObserverContext ctx, Object? value) {
    final name = _providerName(ctx);
    final delta = _deltaMs(ctx);
    final val = _fmtValue(value);

    logI(_line(
      event: 'add',
      provider: name,
      deltaMs: delta,
      value: val,
    ));
  }

  void _logUpdate(ProviderObserverContext ctx, Object? prev, Object? next) {
    final name = _providerName(ctx);
    final delta = _deltaMs(ctx);

    logD(_line(
      event: 'update',
      provider: name,
      deltaMs: delta,
      previous: _fmtValue(prev),
      next: _fmtValue(next),
    ));
  }

  void _logDispose(ProviderObserverContext ctx) {
    final name = _providerName(ctx);
    logW(_line(
      event: 'dispose',
      provider: name,
    ));
  }

  // Jednowierszowa reprezentacja: JSONL lub key=value
  String _line({
    required String event,
    required String provider,
    int? deltaMs,
    String? value,
    String? previous,
    String? next,
  }) {

    if (format == LogFormat.jsonl) {
      final map = <String, Object?>{
        'env': env,
        'event': event, // add/update/dispose
        'provider': provider,
        if (deltaMs != null) 'delta_ms': deltaMs,
        if (value != null) 'value': value,
        if (previous != null) 'prev': previous,
        if (next != null) 'next': next,
      };
      return jsonEncode(map); // → JSON line
    } else {
      // key=value (łatwe do grepowania i czytelne)
      final parts = <String>[
        'env=$env',
        'event=$event',
        'provider=$provider',
        if (deltaMs != null) 'delta_ms=$deltaMs',
        if (value != null) 'value="$value"',
        if (previous != null) 'prev="$previous"',
        if (next != null) 'next="$next"',
      ];
      return parts.join(' | ');
    }
  }

  // -------- overrides

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (_shouldLog(context)) _logAdd(context, value);
    super.didAddProvider(context, value);
  }

  @override
  void didUpdateProvider(
      ProviderObserverContext context,
      Object? previousValue,
      Object? newValue,
      ) {
    if (_shouldLog(context)) _logUpdate(context, previousValue, newValue);
    super.didUpdateProvider(context, previousValue, newValue);
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    if (_shouldLog(context)) _logDispose(context);
    super.didDisposeProvider(context);
  }
}

enum LogFormat { jsonl, kv }
