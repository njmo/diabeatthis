import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';

@RoutePage()
class TestPage extends ConsumerWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorAge = ref.watch(sensorAgeProvider);
    final canulaAge = ref.watch(canulaAgeProvider);
    final bolusWizards = ref.watch(bolusWizardsProvider);

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
              bolusWizards.when(
                data: (bolusWizardList) {
                  return ListView.builder(
                    itemBuilder: (context, index) {
                      final bolusWizard = bolusWizardList[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            bolusWizard.getIcon(),
                            color: bolusWizard.getColor(),
                          ),
                          title: Text(bolusWizard.getParts()),
                          subtitle: Text(
                            'Data: ${bolusWizard.createdAt.toLocal().toIso8601String()}',
                          ),
                        ),
                      );
                    },
                    itemCount: bolusWizardList.length,
                    shrinkWrap: true,
                  );
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
