import 'package:diabeatthis/common/navigation/step_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns the root when history is exhausted', () {
    final history = StepHistory(root: 'dismiss');
    expect(history.pop(), 'dismiss');
    history.reset();
    expect(history.pop(), 'dismiss');
    expect(history.pop(), 'dismiss');
  });

  test('returns visited steps in reverse order', () {
    final history = StepHistory(root: 'dismiss');
    history.reset();
    history.push('search');
    history.push('portion');
    history.push('amount');
    expect(history.pop(), 'amount');
    expect(history.pop(), 'portion');
    expect(history.pop(), 'search');
    expect(history.pop(), 'dismiss');
  });

  test('skips consecutive duplicates but keeps repeated visits', () {
    final history = StepHistory(root: 'dismiss');
    history.reset();
    history.push('search');
    history.push('search');
    history.push('portion');
    history.push('search');
    expect(history.pop(), 'search');
    expect(history.pop(), 'portion');
    expect(history.pop(), 'search');
    expect(history.pop(), 'dismiss');
  });

  test('reset discards steps from the previous editing session', () {
    final history = StepHistory(root: 'dismiss');
    history.reset();
    history.push('search');
    history.push('amount');
    history.reset();
    expect(history.pop(), 'dismiss');
    expect(history.pop(), 'dismiss');
  });
}
