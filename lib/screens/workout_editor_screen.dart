import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/preferences_controller.dart';
import '../controllers/workout_controller.dart';
import '../models/workout_plan.dart';

class WorkoutEditorScreen extends StatefulWidget {
  final WorkoutPlan? plan;

  const WorkoutEditorScreen({super.key, this.plan});

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  late String _equipmentTag;
  late int _effortPreference;

  int _initialEffort = 3;

  bool _defaultsReady = false;
  bool _saving = false;
  bool _confirmingLeave = false;

  String? _saveError;

  bool get _hasChanges {
    if (!_defaultsReady) return false;

    return _titleController.text != (widget.plan?.title ?? '') ||
        _noteController.text != (widget.plan?.planNote ?? '') ||
        _equipmentTag != (widget.plan?.equipmentTag ?? 'None') ||
        _effortPreference != _initialEffort;
  }

  @override
  void initState() {
    super.initState();

    final plan = widget.plan;

    _titleController = TextEditingController(text: plan?.title ?? '');
    _noteController = TextEditingController(text: plan?.planNote ?? '');
    _equipmentTag = plan?.equipmentTag ?? 'None';
    _effortPreference = plan?.effortPreference ?? 3;

    if (plan != null) {
      _initialEffort = plan.effortPreference;
      _defaultsReady = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final controller = context.read<PreferencesController>();

        if (!controller.hasLoaded && !controller.isBusy) {
          controller.load();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = context.watch<PreferencesController>();

    if (!_defaultsReady && controller.hasLoaded) {
      _initialEffort = controller.preferences.defaultEffort;
      _effortPreference = _initialEffort;
      _defaultsReady = true;
    }
  }

  Future<void> _requestLeave() async {
    if (_saving || _confirmingLeave) return;

    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    _confirmingLeave = true;

    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (discard == true) {
        Navigator.of(context).pop();
      }
    } finally {
      _confirmingLeave = false;
    }
  }

  Future<void> _save() async {
    final controller = context.read<WorkoutController>();

    if (_saving || controller.isBusy || !_defaultsReady) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final plan = WorkoutPlan(
      id: widget.plan?.id,
      title: _titleController.text,
      equipmentTag: _equipmentTag,
      planNote: _noteController.text,
      effortPreference: _effortPreference,
    );

    final saved = await controller.savePlan(plan);

    if (!mounted) return;

    if (saved != null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = false;
      _saveError = controller.error ?? 'Could not save your workout.';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workoutController = context.watch<WorkoutController>();
    final preferencesController = context.watch<PreferencesController>();
    final busy = _saving || workoutController.isBusy;

    return PopScope<void>(
      canPop: !busy && !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _requestLeave();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: busy ? null : _requestLeave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            widget.plan == null ? 'Add workout plan' : 'Edit workout plan',
          ),
        ),
        body: !_defaultsReady
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: preferencesController.isBusy
                      ? const CircularProgressIndicator(
                          semanticsLabel: 'Loading preferences',
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              preferencesController.error ??
                                  'Loading your workout defaults.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: preferencesController.load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                ),
              )
            : Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Workout title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a workout title.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _equipmentTag,
                      decoration: const InputDecoration(
                        labelText: 'Equipment',
                        border: OutlineInputBorder(),
                      ),
                      items: WorkoutPlan.equipmentTags
                          .map(
                            (tag) => DropdownMenuItem<String>(
                              value: tag,
                              child: Text(tag),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value == null) return;

                              setState(() => _equipmentTag = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      enabled: !busy,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Plan note',
                        helperText: 'Record your own exercise choices.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Effort preference: $_effortPreference of 5',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: _effortPreference.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$_effortPreference',
                      semanticFormatterCallback: (value) =>
                          'Effort preference ${value.round()} of 5',
                      onChanged: busy
                          ? null
                          : (value) {
                              setState(() {
                                _effortPreference = value.round();
                              });
                            },
                    ),
                    const Text(
                      'This is your subjective effort preference, '
                      'not a fitness or medical recommendation.',
                    ),
                    if (_saveError != null) ...[
                      const SizedBox(height: 16),
                      Text(_saveError!, semanticsLabel: 'Error: $_saveError'),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : _save,
                      child: Text(_saving ? 'Saving...' : 'Save plan'),
                    ),
                    TextButton(
                      onPressed: busy ? null : _requestLeave,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
