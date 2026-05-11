String mealStatusAfterAddOn(String? status) {
  switch (status) {
    case 'eating-then-bolus':
      return 'eating-then-bolus';
    case 'bolused-eating':
      return 'bolused-eating';
    case 'waited-eating':
      return 'waited-eating';
    default:
      return 'eating-extra';
  }
}
