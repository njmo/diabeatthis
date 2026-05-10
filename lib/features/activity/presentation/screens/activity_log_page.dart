import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class ActivityLogPage extends ConsumerWidget {
  final int activityLogId;

  const ActivityLogPage({super.key, required this.activityLogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Aktywność $activityLogId')),
      body: SizedBox.shrink(),
    );
  }
}
