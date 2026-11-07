const familyRecordTime = 1730000000000;

Map<String, dynamic> mirrorRow(
  String kind,
  int id,
  Map<String, dynamic> payload,
) => {
  'kind': kind,
  'id': '$id',
  'payload': {'id': id, ...payload},
  'deleted': false,
};

List<Map<String, dynamic>> familyCollectionFixtures({
  String status = 'planned',
}) => [
  mirrorRow('ingredients', 1, {
    'name': 'Apple',
    'brand': 'Farm',
    'carbs_per_100g': 15.0,
    'fat_per_100g': 1.0,
    'fiber_per_100g': 3.0,
    'protein_per_100g': 2.0,
    'carbs_label_mode': 'non_eu',
    'nutrition_confidence': .8,
    'is_reference': 0,
    'created_at': familyRecordTime - 10000,
    'updated_at': familyRecordTime + 10000,
  }),
  mirrorRow('meals', 2, {
    'name': 'Lunch',
    'status': status,
    'purpose': 'meal',
    'category': null,
    'planned_at': familyRecordTime,
    'summarized_at': null,
    'created_at': familyRecordTime,
    'updated_at': familyRecordTime,
  }),
  mirrorRow('mealIngredients', 3, {
    'meal_id': 2,
    'ingredient_id': 1,
    'amount': 50.0,
    'consumed_amount': 40.0,
    'quantity_confidence': .9,
    'consumed_confidence': .85,
    'grams_per_portion_used': 1.0,
    'entry_type': 'base',
    'created_at': familyRecordTime,
    'updated_at': familyRecordTime,
  }),
  mirrorRow('ingredientHistory', 4, {
    'ingredient_id': 1,
    'carbs_per_100g': 10.0,
    'fat_per_100g': 1.0,
    'fiber_per_100g': 2.0,
    'protein_per_100g': 2.0,
    'nutrition_confidence': .7,
    'created_at': familyRecordTime + 10000,
  }),
  mirrorRow('activities', 5, {
    'name': 'Swimming',
    'percentage_pre': 80,
    'percentage_post': 90,
    'duration_minutes': 45,
  }),
  mirrorRow('activityLogs', 6, {
    'activity_id': 5,
    'started_at': familyRecordTime,
    'ended_at': familyRecordTime + 1800000,
    'intensity': 'high',
    'notes': 'Outside',
    'created_at': familyRecordTime,
    'updated_at': familyRecordTime,
  }),
];

Map<String, dynamic> familySnapshotFixture() => mirrorRow('mealSnapshots', 8, {
  'meal_id': 2,
  'snapshot_type': 'planned',
  'total_grams': 50.0,
  'total_carbs_g': 5.0,
  'total_fiber_g': 1.0,
  'total_net_carbs_g': 4.0,
  'total_fat_g': .5,
  'total_protein_g': 1.0,
  'total_calories_kcal': 28.5,
  'ingredients_count': 1,
  'created_at': familyRecordTime,
  'updated_at': familyRecordTime,
  'calculated_at': null,
});
