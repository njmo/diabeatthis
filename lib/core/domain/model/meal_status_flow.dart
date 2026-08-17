const mealStatusesBlockingAnotherMealActivation = {
  'eating',
  'eating-extra',
  'eating-then-bolus',
  'waiting-for-bolus',
  'bolused-waiting',
  'waited-eating',
  'bolused-eating',
};

bool mealStatusBlocksAnotherMealActivation(String? status) {
  return mealStatusesBlockingAnotherMealActivation.contains(status);
}

bool mealStatusReadyToSummarize(String? status) {
  return status == 'eaten' ||
      status == 'eaten-extra' ||
      status == 'eaten-bolused';
}
