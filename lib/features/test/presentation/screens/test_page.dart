import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
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
      appBar: AppBar(title: Text(context.lang.testPageTitle)),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              sensorAge.when(
                data: (duration) {
                  if (duration == null) {
                    return Text(context.lang.testSensorAgeMissing);
                  }
                  final days = duration.inDays;
                  return Text(context.lang.testSensorAge(days));
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text(context.lang.activityError(error)),
              ),
              canulaAge.when(
                data: (duration) {
                  if (duration == null) {
                    return Text(context.lang.testPodAgeMissing);
                  }
                  final days = duration.inDays;
                  final hours = duration.inHours % 24;
                  return Text(context.lang.testPodAge(days, hours));
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text(context.lang.activityError(error)),
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
                            context.lang.testDateLabel(
                              bolusWizard.createdAt.toLocal().toIso8601String(),
                            ),
                          ),
                        ),
                      );
                    },
                    itemCount: bolusWizardList.length,
                    shrinkWrap: true,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text(context.lang.activityError(error)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
