import 'package:flutter/cupertino.dart';

abstract class Treatment
{
  final int? id;
  final DateTime? dateHappened;

  const Treatment({this.id,
    this.dateHappened,});

  String getParts();
  IconData getIcon();
  Color getColor();
}