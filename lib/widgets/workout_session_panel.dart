import 'package:flutter/material.dart';

import '../controllers/session_controller.dart';
import '../models/training_log.dart';
import 'training_set_editor_dialog.dart';

class WorkoutSessionPanel extends StatefulWidget {
  final SessionController controller;

  const WorkoutSessionPanel({super.key, required this.controller});

  @override
  State<WorkoutSessionPanel> createState() => _WorkoutSessionPanelState();
}

class _WorkoutSessionPanelState extends State<WorkoutSessionPanel> {
  final _startFormKey = GlobalKey<FormState>();
  final _setFormKey = GlobalKey<FormState>();

  final _sessionLabelController = TextEditingController();
  final _exerciseController = TextEditingController();
  final _repetitionsController = TextEditingController();

  bool _dialogOpen = false;

  void _startSession() {
    if (widget.controller.isBusy || _dialogOpen) return;
    if (!_startFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final started = widget.controller.startSession(
      _sessionLabelController.text,
    );

    if (started) {
      _sessionLabelController.clear();
    }
  }

  Future<void> _addSet() async {
    if (widget.controller.isBusy || _dialogOpen) return;
    if (!_setFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final saved = await widget.controller.addSet(
      exerciseLabel: _exerciseController.text,
      repetitions: int.parse(_repetitionsController.text.trim()),
    );

    if (!mounted || !saved) return;

    _setFormKey.currentState?.reset();
    _exerciseController.clear();
    _repetitionsController.clear();
  }

  Future<void> _editSet(TrainingLog log) async {
    if (_dialogOpen || widget.controller.isBusy) return;

    setState(() => _dialogOpen = true);

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            TrainingSetEditorDialog(controller: widget.controller, log: log),
      );
    } finally {
      if (mounted) {
        setState(() => _dialogOpen = false);
      }
    }
  }

  Future<void> _deleteSet(TrainingLog log) async {
    if (_dialogOpen || widget.controller.isBusy) return;

    final id = log.id;
    if (id == null) return;

    setState(() => _dialogOpen = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete set?'),
          content: Text(
            'Delete "${log.exerciseLabel}" '
            'with ${log.repetitions} repetitions? '
            'The session will remain open.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      await widget.controller.deleteSet(id);
    } finally {
      if (mounted) {
        setState(() => _dialogOpen = false);
      }
    }
  }

  Future<void> _resetSession() async {
    if (_dialogOpen || widget.controller.isBusy) return;

    setState(() => _dialogOpen = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reset session?'),
          content: const Text(
            'Discard this unfinished session and its sets? '
            'Completed sessions will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      final reset = await widget.controller.resetSession();

      if (!mounted || !reset) return;

      _exerciseController.clear();
      _repetitionsController.clear();
    } finally {
      if (mounted) {
        setState(() => _dialogOpen = false);
      }
    }
  }

  Future<void> _finishSession() async {
    if (_dialogOpen || widget.controller.isBusy) return;

    final finished = await widget.controller.finishSession();

    if (!mounted || !finished) return;

    _exerciseController.clear();
    _repetitionsController.clear();

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Session finished.')));
  }

  @override
  void dispose() {
    _sessionLabelController.dispose();
    _exerciseController.dispose();
    _repetitionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final controller = widget.controller;
        final busy = controller.isBusy || _dialogOpen;
        final logs = controller.sessionLogs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Workout session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (controller.error != null) ...[
              Text(
                controller.error!,
                semanticsLabel: 'Error: ${controller.error}',
              ),
              const SizedBox(height: 12),
            ],
            if (controller.isBusy) ...[
              const LinearProgressIndicator(semanticsLabel: 'Updating session'),
              const SizedBox(height: 16),
            ],
            if (!controller.hasLoaded)
              FilledButton(
                onPressed: busy ? null : controller.load,
                child: const Text('Reload session'),
              )
            else if (!controller.hasActiveSession)
              Form(
                key: _startFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _sessionLabelController,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Session label',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a session label.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: busy ? null : _startSession,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start session'),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                controller.sessionLabel!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Sets logged: ${logs.length}'),
              const SizedBox(height: 16),
              Form(
                key: _setFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _exerciseController,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Exercise label',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter an exercise label.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _repetitionsController,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Repetitions',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final repetitions = int.tryParse(value?.trim() ?? '');

                        if (repetitions == null || repetitions <= 0) {
                          return 'Enter a positive whole number.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: busy ? null : _addSet,
                      icon: const Icon(Icons.add),
                      label: const Text('Add set'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (logs.isEmpty)
                const Text('No sets logged in this session yet.')
              else
                ...logs.map(
                  (log) => Card(
                    key: ValueKey(log.id),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            log.exerciseLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text('${log.repetitions} repetitions'),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: busy ? null : () => _editSet(log),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit set'),
                              ),
                              TextButton.icon(
                                onPressed: busy ? null : () => _deleteSet(log),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete set'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy || logs.isEmpty ? null : _finishSession,
                icon: const Icon(Icons.check),
                label: const Text('Finish session'),
              ),
              TextButton.icon(
                onPressed: busy ? null : _resetSession,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset session'),
              ),
            ],
          ],
        );
      },
    );
  }
}
