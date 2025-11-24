import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'simple_provider.g.dart';
part 'simple_provider.freezed.dart';

@freezed
class Human with _$Human {
  @override
  final String name;
  @override
  final int age;
  @override
  final int num;

  Human({required this.name, required this.age, required this.num});
}

@riverpod
int randomNumber(Ref ref) {
  return Random().nextInt(100);
}

Future<int> getNumberFromApi(Ref ref) async {
  final randomNumber = ref.read(randomNumberProvider);
  await Future.delayed(const Duration(seconds: 2));
  return randomNumber;
}

@riverpod
Stream<int> randomNumberStream(Ref ref) async* {
  while (true) {
    final number = await getNumberFromApi(ref);
    yield number;
    await Future.delayed(const Duration(seconds: 1));
  }
}

@riverpod
void numberReader(Ref ref) {
  ref.listen<AsyncValue<int>>(randomNumberStreamProvider, (previous, next) {
    next.whenData((number) {
      final humanNotifier = ref.read(humanProvider.notifier);
      humanNotifier.setNumber(number);
    });
  });
}

@riverpod
class HumanNotifier extends _$HumanNotifier {
  @override
  Human build() {
    return Human(name: 'Oliwier Kłonica', age: 8, num: 42);
  }

  void setAge(int age) => state = state.copyWith(age: age);
  void setName(String name) => state = state.copyWith(name: name);
  void setNumber(int number) => state = state.copyWith(num: number);
}

@riverpod
int age(Ref ref) {
  return ref.watch(humanProvider.select((h) => h.age));
}
@riverpod
String name(Ref ref) {
  return ref.watch(humanProvider.select((h) => h.name));
}
@riverpod
int number(Ref ref) {
  return ref.watch(humanProvider.select((h) => h.num));
}