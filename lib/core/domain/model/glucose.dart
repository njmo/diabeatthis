import 'package:freezed_annotation/freezed_annotation.dart';

part 'glucose.freezed.dart';

@freezed
abstract class Glucose with _$Glucose{
  const factory Glucose({
    required int id,
    required DateTime date,
    required int sgv,
    required String direction,
  }) = _Glucose;
}

/*


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'svg': sgv,
      'direction': direction,
    };
  }

  factory Glucose.fromJson(Map<String, dynamic> map) => Glucose(
      date: (map['date'] as num).toInt(),
      sgv: (map['sgv'] as num).toInt(),
      direction: map['direction']);
 */