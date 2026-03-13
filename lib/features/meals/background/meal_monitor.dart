import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/meal_database_provider.dart';

abstract interface class ScheduledTask {
  void start();
  void stop();
  void tick();
}


class MealMonitor implements ScheduledTask {
  final ProviderContainer _container;
  bool _isRunning = false;

  MealMonitor(this._container);

  @override
  void start()
  {
    _isRunning = true;
    _container.read(mealsForTodayStreamProvider);
  }

  @override
  void stop()
  {
    _isRunning = false;

  }

  @override
  void tick()
  {

  }

  bool isRunning() => _isRunning;
}