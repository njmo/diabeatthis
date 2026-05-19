import 'package:flutter/cupertino.dart';

abstract class Treatment {
  final DateTime? createdAt;

  const Treatment({this.createdAt});

  bool get isValid;
  String getParts();
  IconData getIcon();
  Color getColor();
}
