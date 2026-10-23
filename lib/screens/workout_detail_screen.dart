import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout_plan.dart';
import '../repositories/workout_repository.dart';
import 'workout_editor_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final int workoutId;

  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Future<WorkoutPlan?> _planFuture;

  bool _editing = false;

  @override
  void initState() {
    super.initState();

    _planFuture = _loadPlan();
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
    if (_editing) return;

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout details')),
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
              Text('Plan note', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                plan.planNote.isEmpty ? 'No plan note added.' : plan.planNote,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _editing ? null : () => _editPlan(plan),
                icon: const Icon(Icons.edit),
                label: const Text('Edit plan'),
              ),
            ],
          );
        },
      ),
    );
  }
}
