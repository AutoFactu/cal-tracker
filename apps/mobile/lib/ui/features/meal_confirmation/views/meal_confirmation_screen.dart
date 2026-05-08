import 'package:flutter/material.dart';

import '../../../core/design_system.dart';

class MealConfirmationScreen extends StatelessWidget {
  const MealConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: FreshColors.screen,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: FreshCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FreshIconChip(
                    icon: Icons.check_rounded,
                    color: FreshColors.limeDeep,
                  ),
                  SizedBox(height: FreshSpacing.md),
                  Text('Meal confirmation is embedded in the logging flow.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
