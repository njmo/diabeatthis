import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/notifier_provider/simple_provider.dart';

@RoutePage()
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final age = ref.watch(ageProvider);
    final name = ref.watch(nameProvider);
    final number = ref.watch(numberProvider);

    final human = ref.read(humanProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Column(
        children: [
          Text('Welcome $name!'),
          const SizedBox(height: 8),
          Text('Your age is $age.'),
          const SizedBox(height: 16),
          Text('Your number is $number.'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    human.setAge(Random().nextInt(500));
                  },
                  child: Icon(Icons.ac_unit),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    human.setName('asdasd + ${Random().nextInt(500)}');
                  },
                  child: Icon(Icons.abc_outlined),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: TextButton(
                    onPressed: () {
                      context.router.push(
                        routes.TestRoute()
                      ); // ⬅️ użyj aliasu, unikniesz konfliktów nazw
                    },
                    child: Text('test'),
                  ),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: TextButton(
                    onPressed: () {
                      context.router.push(
                          routes.AddMealRoute()
                      );
                    },
                    child: Text('Add meal'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
