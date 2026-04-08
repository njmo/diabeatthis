import 'package:flutter/cupertino.dart';

abstract class Treatment
{
  final int? id;
  final DateTime? createdAt;

  const Treatment({this.id,
    this.createdAt,});

  String getParts();
  IconData getIcon();
  Color getColor();
}