import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/preferences_controller.dart';
import '../models/workout_plan.dart';
import '../repositories/training_log_repository.dart';
import '../repositories/workout_repository.dart';
import '../services/gear_match_service.dart';

class GearMatchPanel extends StatefulWidget {
  final bool enabled;
  final ValueChanged<WorkoutPlan> onViewPlan;

  const GearMatchPanel({
    super.key,
    required this.onViewPlan,
    this.enabled = true,
  });

  @override
  State<GearMatchPanel> createState() => _GearMatchPanelState();
}

class _GearMatchPanelState extends State<GearMatchPanel> {
  final _service = GearMatchService();

  GearMatchResult? _result;
  String? _message;

  bool _loading = false;

  Future<void> _recommend() async {
    if (_loading || !widget.enabled) return;

    setState(() {
      _loading = true;
      _result = null;
      _message = null;
    });

    try {
      final preferences = context.read<PreferencesController>();
      final workouts = context.read<WorkoutRepository>();
      final trainingLogs = context.read<TrainingLogRepository>();

      if (!preferences.hasLoaded) {
        final loaded = await preferences.load();

        if (!mounted) return;

        if (!loaded) {
          setState(() {
            _message =
                preferences.error ??
                'Could not load your equipment preference. Try again.';
          });
          return;
        }
      }

      final equipmentPreference = preferences.preferences.equipmentPreference;

      final plans = await workouts.getPlans();
      final logs = await trainingLogs.getLogs();

      if (!mounted) return;

      final result = _service.recommend(
        plans: plans,
        logs: logs,
        equipmentPreference: equipmentPreference,
      );

      setState(() {
        _result = result;

        if (result == null) {
          _message = 'Add a workout plan, then try Gear Match again.';
        }
      });
    } on ArgumentError {
      if (!mounted) return;

      setState(() {
        _message =
            'Gear Match received invalid input. Check your saved plans '
            'and equipment preference.';
      });
    } on StateError {
      if (!mounted) return;

      setState(() {
        _message =
            'Gear Match could not use the saved session data. '
            'Check your training history.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _message = 'Could not load a recommendation. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _dismiss() {
    setState(() {
      _result = null;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || !widget.enabled;
    final result = _result;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Gear Match', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Choose from your saved plans using equipment preference '
              'and your most recently completed session.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : _recommend,
              icon: const Icon(Icons.search),
              label: Text(_loading ? 'Finding a plan...' : 'Find a plan'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, semanticsLabel: 'Gear Match: $_message'),
            ],
            if (result != null) ...[
              const SizedBox(height: 16),
              Text(
                'Suggested plan: ${result.plan.title}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Rule score: ${result.score} of 3'),
              const SizedBox(height: 8),
              Text(result.reason),
              const SizedBox(height: 8),
              const Text(
                'This is a rule-based suggestion, '
                'not fitness or medical advice.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            final plan = result.plan;
                            _dismiss();
                            widget.onViewPlan(plan);
                          },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View plan'),
                  ),
                  TextButton(
                    onPressed: busy ? null : _dismiss,
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
