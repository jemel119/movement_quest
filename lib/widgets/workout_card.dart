import 'package:flutter/material.dart';

import '../models/workout_plan.dart';

class WorkoutCard extends StatelessWidget {
  final WorkoutPlan plan;

  const WorkoutCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Equipment: ${plan.equipmentTag}'),
            Text('Effort preference: ${plan.effortPreference} of 5'),
            if (plan.planNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plan.planNote),
            ],
          ],
        ),
      ),
    );
  }
}
