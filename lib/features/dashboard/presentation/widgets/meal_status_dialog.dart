import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MealStatusDialog extends ConsumerWidget {
  const MealStatusDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'What you are going to do ?',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      ),
      content: Padding(
        padding: EdgeInsetsGeometry.directional(top: 10),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsetsGeometry.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                  color: Colors.white70,
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop('eaten');
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_outlined, size: 60),
                      Text('Eat'),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Container(
                padding: EdgeInsetsGeometry.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                  color: Colors.white70,
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop('skipped');
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(Icons.no_meals, size: 60), Text('Skip')],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
