import 'dart:convert';

import 'package:drift/drift.dart';

import '../database_impl.dart';

Future<List<Map<String, dynamic>>> loadFamilyPlanRows(
  DatabaseImpl db,
  Map<String, dynamic> plan,
) async {
  final rows = <String, Map<String, dynamic>>{};
  void collect(List<QueryRow> values) {
    for (final row in values) {
      rows['${row.data['kind']}/${row.data['entity_id']}'] = {
        'kind': row.data['kind'],
        'id': row.data['entity_id'],
        'revision': row.data['revision'],
        'deleted': row.read<int>('deleted') == 1,
        'payload': row.data['payload'] == null
            ? null
            : jsonDecode(row.read<String>('payload')),
      };
    }
  }

  Future<Map?> add(String kind, Object id) async {
    final found = await db
        .customSelect(
          'SELECT * FROM family_sync_outbox WHERE kind=? AND entity_id=?',
          variables: [Variable(kind), Variable('$id')],
        )
        .get();
    collect(found);
    return found.isEmpty || found.first.data['payload'] == null
        ? null
        : jsonDecode(found.first.read<String>('payload')) as Map;
  }

  final type = plan['type'] as String;
  final values = plan['values'] as Map;
  if (type.endsWith('Meal')) {
    if (type == 'updateMeal') {
      await add('meals', plan['targetId']);
      collect(
        await db
            .customSelect(
              "SELECT * FROM family_sync_outbox WHERE kind IN ('mealIngredients','mealHistory','mealSnapshots') AND deleted=0 AND json_extract(payload,'\$.meal_id')=?",
              variables: [Variable(plan['targetId'] as int)],
            )
            .get(),
      );
      for (final row in rows.values.toList().where(
        (r) => r['kind'] == 'mealIngredients' && r['deleted'] != true,
      )) {
        final payload = row['payload'] as Map;
        await add('ingredients', payload['ingredient_id']);
        if (payload['portion_id'] != null) {
          await add('portions', payload['portion_id']);
        }
      }
    }
    for (final item in values['ingredients'] as List) {
      if (item['ingredientId'] != null) {
        await add('ingredients', item['ingredientId']);
      }
    }
  } else if (type == 'planActivity') {
    await add('activities', values['activityId']);
  } else {
    final occurrence = await add('activityOccurrences', plan['targetId']);
    if (occurrence != null) {
      await add('activities', occurrence['activity_id']);
      if (occurrence['schedule_id'] != null) {
        await add('activitySchedules', occurrence['schedule_id']);
      }
      if (occurrence['activity_log_id'] != null) {
        await add('activityLogs', occurrence['activity_log_id']);
      }
    }
  }
  return rows.values.toList();
}
