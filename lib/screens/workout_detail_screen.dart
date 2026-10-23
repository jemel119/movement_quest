import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../models/workout_plan.dart';
import '../repositories/training_log_repository.dart';
import '../repositories/workout_repository.dart';
import '../widgets/workout_session_panel.dart';
import 'workout_editor_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final int workoutId;

  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Future<WorkoutPlan?> _planFuture;
  late final SessionController _sessionController;

  bool _editing = false;

  @override
  void initState() {
    super.initState();

    _planFuture = _loadPlan();

    _sessionController = SessionController(
      context.read<TrainingLogRepository>(),
      workoutId: widget.workoutId,
    );

    _sessionController.load();
  }

  Future<WorkoutPlan?> _loadPlan() {
    return context.read<WorkoutRepository>().getPlan(widget.workoutId);
  }

  void _reload() {
    setState(() {
      _planFuture = _loadPlan();
    });
  }

  Future<void> _editPlan(WorkoutPlan plan) async {
    if (_editing || _sessionController.isBusy) return;

    setState(() => _editing = true);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => WorkoutEditorScreen(plan: plan)),
    );

    if (!mounted) return;

    setState(() {
      _editing = false;
      _planFuture = _loadPlan();
    });
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sessionController,
      builder: (context, child) {
        return PopScope<void>(
          canPop: !_sessionController.isBusy,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Workout details'),
              leading: BackButton(
                onPressed: _sessionController.isBusy
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
            ),
            body: FutureBuilder<WorkoutPlan?>(
              future: _planFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Loading workout details',
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Could not load this workout. Try again.'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final plan = snapshot.data;

                if (plan == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('This workout plan no longer exists.'),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      plan.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text('Equipment: ${plan.equipmentTag}'),
                    const SizedBox(height: 8),
                    Text('Effort preference: ${plan.effortPreference} of 5'),
                    const SizedBox(height: 24),
                    Text(
                      'Plan note',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.planNote.isEmpty
                          ? 'No plan note added.'
                          : plan.planNote,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _editing || _sessionController.isBusy
                          ? null
                          : () => _editPlan(plan),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit plan'),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    WorkoutSessionPanel(controller: _sessionController),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
