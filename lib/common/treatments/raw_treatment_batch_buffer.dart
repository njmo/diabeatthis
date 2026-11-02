import 'dart:async';
import 'dart:convert';

/// Collects local broadcasts before treatment parsing, with a bounded lifetime.
class RawTreatmentBatchBuffer {
  RawTreatmentBatchBuffer({
    required this.onBatch,
    required this.onError,
    this.onPendingWizards,
    this.settleDelay = const Duration(seconds: 1),
    this.maximumWait = const Duration(seconds: 10),
  });

  final Future<void> Function(List<Map<String, dynamic>>) onBatch;
  final Future<void> Function(List<Map<String, dynamic>>)? onPendingWizards;
  final void Function(Object, StackTrace) onError;
  final Duration settleDelay;
  final Duration maximumWait;
  final List<Map<String, dynamic>> _pending = [];
  final Set<String> _announcedWizards = {};
  Timer? _settleTimer;
  Timer? _deadlineTimer;
  Future<void> _processing = Future.value();

  void add(Iterable<Map<String, dynamic>> records) {
    _pending.addAll(records.map(Map<String, dynamic>.of));
    if (_pending.isEmpty) return;
    _deadlineTimer ??= Timer(maximumWait, () => unawaited(flush()));
    _settleTimer?.cancel();
    _settleTimer = Timer(settleDelay, () {
      if (_waitingForDelivery) {
        _publishPendingWizards();
        return;
      }
      unawaited(flush());
    });
  }

  void _publishPendingWizards() {
    final publish = onPendingWizards;
    if (publish == null) return;
    final wizards = _pending
        .where(
          (record) =>
              record['isValid'] != false &&
              _type(record) == 'bolus wizard' &&
              _announcedWizards.add(
                jsonEncode([
                  record['_id'],
                  record['created_at'],
                  record['date'],
                  record['bolusCalculatorResult'],
                ]),
              ),
        )
        .toList();
    if (wizards.isEmpty) return;
    _processing = _processing
        .then((_) => publish(wizards))
        .catchError(
          (Object error, StackTrace stackTrace) => onError(error, stackTrace),
        );
  }

  bool get _waitingForDelivery {
    final valid = _pending.where((record) => record['isValid'] != false);
    final wizards = valid.where((record) => _type(record) == 'bolus wizard');
    if (wizards.isEmpty) return false;
    final deliveries = valid.where((record) {
      final insulin = record['insulin'];
      return _type(record) == 'meal bolus' &&
          insulin is num &&
          insulin.isFinite &&
          insulin > 0;
    });
    // A wizard is only a calculation. Keep collecting until delivery records
    // arrive, while the hard deadline also handles failed/missing deliveries.
    return deliveries.length < wizards.length;
  }

  static String _type(Map<String, dynamic> record) =>
      (record['eventType'] ?? '').toString().trim().toLowerCase();

  Future<void> flush() {
    _settleTimer?.cancel();
    _deadlineTimer?.cancel();
    _settleTimer = null;
    _deadlineTimer = null;
    if (_pending.isEmpty) return _processing;
    final batch = List<Map<String, dynamic>>.unmodifiable(_pending);
    _pending.clear();
    _announcedWizards.clear();
    // Preserve ingress order even when a preceding write is still running.
    _processing = _processing
        .then((_) => onBatch(batch))
        .catchError(
          (Object error, StackTrace stackTrace) => onError(error, stackTrace),
        );
    return _processing;
  }
}
