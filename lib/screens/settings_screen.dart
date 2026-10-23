import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/preferences_controller.dart';
import '../models/app_preferences.dart';
import '../models/workout_plan.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppPreferences? _displayedPreferences;
  double _effort = 3;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final controller = context.read<PreferencesController>();

      if (!controller.hasLoaded && !controller.isBusy) {
        controller.load();
      }
    });
  }

  Future<void> _save(AppPreferences preferences) async {
    final controller = context.read<PreferencesController>();

    final saved = await controller.save(preferences);

    if (!mounted) return;

    setState(() {
      _effort = controller.preferences.defaultEffort.toDouble();
    });

    if (saved) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Preferences saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreferencesController>();

    if (!controller.hasLoaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: controller.isLoading
              ? const CircularProgressIndicator(
                  semanticsLabel: 'Loading preferences',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.error ??
                          'Your preferences have not loaded yet.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: controller.load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        ),
      );
    }

    final preferences = controller.preferences;

    if (!identical(_displayedPreferences, preferences)) {
      _displayedPreferences = preferences;
      _effort = preferences.defaultEffort.toDouble();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Workout preferences',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Changes are saved on this device.'),
        const SizedBox(height: 24),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Preferred equipment',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: preferences.equipmentPreference,
              isExpanded: true,
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      _save(preferences.withEquipmentPreference(value));
                    },
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('No preference'),
                ),
                ...WorkoutPlan.equipmentTags.map(
                  (tag) => DropdownMenuItem<String>(
                    value: tag,
                    child: Text(tag == 'None' ? 'No equipment' : tag),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'No preference accepts any equipment. '
          'No equipment means workouts without equipment.',
        ),
        const SizedBox(height: 24),
        Text(
          'Default effort preference: ${_effort.round()} of 5',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: _effort,
          min: 1,
          max: 5,
          divisions: 4,
          label: '${_effort.round()}',
          semanticFormatterCallback: (value) =>
              'Default effort preference ${value.round()} of 5',
          onChanged: controller.isBusy
              ? null
              : (value) {
                  setState(() => _effort = value);
                },
          onChangeEnd: controller.isBusy
              ? null
              : (value) {
                  _save(preferences.withDefaultEffort(value.round()));
                },
        ),
        const Text(
          'This records your preferred effort level, '
          'not a fitness or medical recommendation.',
        ),
        if (controller.isBusy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(semanticsLabel: 'Saving preferences'),
        ],
        if (controller.error != null) ...[
          const SizedBox(height: 16),
          Text(controller.error!, semanticsLabel: 'Error: ${controller.error}'),
        ],
      ],
    );
  }
}
