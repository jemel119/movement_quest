import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/workout_controller.dart';
import '../models/workout_plan.dart';
import '../widgets/workout_card.dart';
import 'workout_editor_screen.dart';

class WorkoutCatalogScreen extends StatefulWidget {
  const WorkoutCatalogScreen({super.key});

  @override
  State<WorkoutCatalogScreen> createState() => _WorkoutCatalogScreenState();
}

class _WorkoutCatalogScreenState extends State<WorkoutCatalogScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final controller = context.read<WorkoutController>();

      if (!controller.hasLoaded && !controller.isBusy) {
        controller.load();
      }
    });
  }

  Future<void> _openEditor({WorkoutPlan? plan}) async {
    final controller = context.read<WorkoutController>();

    if (controller.isBusy) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => WorkoutEditorScreen(plan: plan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutController>(
      builder: (context, controller, child) {
        final plans = controller.plans;
        final error = controller.error;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    children: [
                      Text(
                        'Completed sessions: ${controller.completedSessions}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        tooltip: 'Refresh workouts',
                        onPressed: controller.isBusy
                            ? null
                            : () {
                                controller.load();
                              },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Equipment filter',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: controller.equipmentFilter,
                        isExpanded: true,
                        onChanged: controller.isBusy
                            ? null
                            : controller.setEquipmentFilter,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All equipment'),
                          ),
                          ...WorkoutPlan.equipmentTags.map(
                            (tag) => DropdownMenuItem<String>(
                              value: tag,
                              child: Text(tag),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: controller.isBusy ? null : () => _openEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add plan'),
                  ),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(error, semanticsLabel: 'Error: $error'),
                    TextButton(
                      onPressed: controller.isBusy
                          ? null
                          : () {
                              controller.load();
                            },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (controller.isLoading)
              const LinearProgressIndicator(semanticsLabel: 'Loading workouts'),
            Expanded(
              child: !controller.hasLoaded
                  ? Center(
                      child: Text(
                        controller.isLoading
                            ? 'Loading your workouts...'
                            : 'Your workouts could not be loaded.',
                      ),
                    )
                  : plans.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          controller.equipmentFilter == null
                              ? 'No workout plans yet.'
                              : 'No plans match this equipment filter.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: plans.length,
                      itemBuilder: (context, index) {
                        final plan = plans[index];

                        return WorkoutCard(
                          key: ValueKey(plan.id),
                          plan: plan,
                          onEdit: controller.isBusy
                              ? null
                              : () => _openEditor(plan: plan),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
