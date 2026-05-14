import 'package:flutter/cupertino.dart';

abstract class Treatment {
  final DateTime? createdAt;

  const Treatment({this.createdAt});

  String getParts();
  IconData getIcon();
  Color getColor();
}
