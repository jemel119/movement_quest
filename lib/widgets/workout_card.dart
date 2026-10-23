import 'package:flutter/material.dart';

import '../models/workout_plan.dart';

class WorkoutCard extends StatelessWidget {
  final WorkoutPlan plan;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WorkoutCard({
    super.key,
    required this.plan,
    this.onView,
    this.onEdit,
    this.onDelete,
  });

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
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View plan'),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
