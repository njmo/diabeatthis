import 'package:flutter/material.dart';

class GoogleBrandMark extends StatelessWidget {
  const GoogleBrandMark({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/icons/auth/google_g.png',
      width: size,
      height: size,
    ),
  );
}
