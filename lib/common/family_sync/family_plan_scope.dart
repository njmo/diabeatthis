/// Read-only aggregate inputs used to detect offline child edits.
List<Map<String, dynamic>> familyPlanScope(
  List<Map<String, dynamic>> rows,
  Map<String, dynamic> plan,
) {
  final selected = <String, Map<String, dynamic>>{};
  Map<String, dynamic> add(String kind, Object id) {
    final row = rows.singleWhere(
      (r) => r['kind'] == kind && r['id'] == '$id' && r['deleted'] != true,
    );
    selected['$kind/${row['id']}'] = row;
    return Map<String, dynamic>.from(row['payload'] as Map);
  }

  final type = plan['type'] as String;
  final values = plan['values'] as Map;
  if (type == 'setActivityScheduleEnabled') {
    final schedule = add('activitySchedules', plan['targetId']);
    add('activities', schedule['activity_id']);
    for (final row in rows.where(
      (r) =>
          r['kind'] == 'activityOccurrences' &&
          r['deleted'] != true &&
          (r['payload'] as Map)['schedule_id'] == plan['targetId'] &&
          ((r['payload'] as Map)['started_at'] as int) >
              (values['effectiveFrom'] as int),
    )) {
      final p = add('activityOccurrences', row['id']);
      if (p['activity_log_id'] != null) {
        add('activityLogs', p['activity_log_id']);
      }
    }
  } else if ([
    'createActivity',
    'updateActivity',
    'createActivitySchedule',
  ].contains(type)) {
    if (type != 'createActivity') add('activities', plan['targetId']);
  } else if (type.endsWith('Meal')) {
    if (type == 'updateMeal') {
      add('meals', plan['targetId']);
      for (final row in rows.where(
        (r) =>
            [
              'mealIngredients',
              'mealHistory',
              'mealSnapshots',
            ].contains(r['kind']) &&
            r['deleted'] != true &&
            (r['payload'] as Map)['meal_id'] == plan['targetId'],
      )) {
        selected['${row['kind']}/${row['id']}'] = row;
        if (row['kind'] == 'mealIngredients') {
          final payload = row['payload'] as Map;
          add('ingredients', payload['ingredient_id']);
          if (payload['portion_id'] != null) {
            add('portions', payload['portion_id']);
          }
        }
      }
    }
    for (final item in values['ingredients'] as List) {
      if (item['ingredientId'] != null) {
        add('ingredients', item['ingredientId']);
      }
    }
  } else if (['planActivity', 'startActivity', 'logActivity'].contains(type)) {
    if (values['activityId'] != null) add('activities', values['activityId']);
  } else {
    final occurrence = add('activityOccurrences', plan['targetId']);
    add('activities', occurrence['activity_id']);
    if (occurrence['schedule_id'] != null) {
      add('activitySchedules', occurrence['schedule_id']);
    }
    if (occurrence['activity_log_id'] != null) {
      add('activityLogs', occurrence['activity_log_id']);
    }
  }
  final result = selected.values.toList()
    ..sort(
      (a, b) => '${a['kind']}/${a['id']}'.compareTo('${b['kind']}/${b['id']}'),
    );
  return result;
}

List<Map<String, dynamic>> familyPlanVersions(
  List<Map<String, dynamic>> rows,
) => [
  for (final row in rows)
    {'kind': row['kind'], 'id': row['id'], 'revision': row['revision']},
];
