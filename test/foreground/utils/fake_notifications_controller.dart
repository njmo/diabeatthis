import 'dart:async';
import 'dart:collection';

import 'package:diabeatthis/core/notifications/base/notifications_controller.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';

class FakeNotificationsController implements NotificationsController {
  final shownEvents = <NotificationEvent>[];
  final scheduledEvents = <({NotificationEvent event, Duration duration})>[];
  final cancelledIds = <int>[];
  bool cancelAllCalled = false;

  NotificationEvent get lastShownEvent {
    final event = shownEvents.last;
    shownEvents.removeLast();
    return event;
  }

  final Queue<Future<void> Function()> _showResponses = Queue();
  final Queue<Future<void> Function()> _scheduleResponses = Queue();
  final Queue<Future<void> Function()> _cancelResponses = Queue();
  Future<Iterable<int>> pendingResult = Future.value(const []);

  void enqueueShowSuccess() {
    _showResponses.add(() async {});
  }

  void enqueueShowError(Object error) {
    _showResponses.add(() async => throw error);
  }

  void enqueueScheduleSuccess() {
    _scheduleResponses.add(() async {});
  }

  void enqueueScheduleError(Object error) {
    _scheduleResponses.add(() async => throw error);
  }

  void enqueueCancelSuccess() {
    _cancelResponses.add(() async {});
  }

  void enqueueCancelError(Object error) {
    _cancelResponses.add(() async => throw error);
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> show(NotificationEvent event) async {
    shownEvents.add(event);

    if (_showResponses.isEmpty) return;
    await _showResponses.removeFirst()();
  }

  @override
  Future<void> schedule(NotificationEvent event, Duration duration) async {
    scheduledEvents.add((event: event, duration: duration));

    if (_scheduleResponses.isEmpty) return;
    await _scheduleResponses.removeFirst()();
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);

    if (_cancelResponses.isEmpty) return;
    await _cancelResponses.removeFirst()();
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
  }

  @override
  Future<Iterable<int>> get pending => pendingResult;
}