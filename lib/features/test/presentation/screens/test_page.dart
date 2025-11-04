import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/provider/nightscout_repository_provider.dart';
import '../providers/device_status_provider.dart';

@RoutePage()
class TestPage extends ConsumerWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorAge = ref.watch(sensorAgeProvider);
    final canulaAge = ref.watch(canulaAgeProvider);
    final deviceStatusStream = ref.watch(deviceStatusStreamProvider);
    final meals = ref.watch(mealsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Test Page')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              sensorAge.when(
                data: (duration) {
                  if (duration == null) {
                    return const Text('Brak danych o wieku sensora');
                  }
                  final days = duration.inDays;
                  return Text('Sensor działa od $days dni');
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Błąd: $error'),
              ),
              canulaAge.when(
                data: (duration) {
                  if (duration == null) {
                    return const Text('Brak danych o wieku poda');
                  }
                  final days = duration.inDays;
                  final hours = duration.inHours % 24;
                  return Text('Pompa działa od $days dni i $hours godzin');
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Błąd: $error'),
              ),
              deviceStatusStream.when(
                data: (status) {
                  return Text('Ostatni status urządzenia: ${status.date.toLocal().toIso8601String()}');
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Błąd: $error'),
              ),
              const SizedBox(height: 15),
              meals.when(
                data: (mealsList) {
                  return ListView.builder(itemBuilder: (context, index) {
                    final meal = mealsList[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(meal.getIcon(), color: meal.getColor()),
                        title: Text(meal.getParts()),
                        subtitle: Text('Data: ${meal.eatenAt?.toLocal().toIso8601String()}'),
                      ),
                    );
                  }, itemCount: mealsList.length, shrinkWrap: true,);
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Błąd: $error'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
