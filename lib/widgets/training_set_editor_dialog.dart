import 'package:flutter/material.dart';

import '../controllers/session_controller.dart';
import '../models/training_log.dart';

class TrainingSetEditorDialog extends StatefulWidget {
  final SessionController controller;
  final TrainingLog log;

  const TrainingSetEditorDialog({
    super.key,
    required this.controller,
    required this.log,
  });

  @override
  State<TrainingSetEditorDialog> createState() =>
      _TrainingSetEditorDialogState();
}

class _TrainingSetEditorDialogState extends State<TrainingSetEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _exerciseController;
  late final TextEditingController _repetitionsController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _exerciseController = TextEditingController(text: widget.log.exerciseLabel);
    _repetitionsController = TextEditingController(
      text: '${widget.log.repetitions}',
    );
  }

  Future<void> _save() async {
    final controller = widget.controller;

    if (_saving || controller.isBusy || !controller.hasLoaded) {
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final id = widget.log.id;
    if (id == null) return;

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    final saved = await controller.editSet(
      logId: id,
      exerciseLabel: _exerciseController.text,
      repetitions: int.parse(_repetitionsController.text.trim()),
    );

    if (!mounted) return;

    if (saved) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = false);
  }

  @override
  void dispose() {
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
        final busy = _saving || controller.isBusy;

        return PopScope<void>(
          canPop: !busy,
          child: AlertDialog(
            title: const Text('Edit set'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 16),
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
                    if (controller.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        controller.error!,
                        semanticsLabel: 'Error: ${controller.error}',
                      ),
                    ],
                    if (!controller.hasLoaded) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: busy ? null : controller.load,
                        child: const Text('Reload session'),
                      ),
                    ],
                    if (busy) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(
                        semanticsLabel: 'Updating set',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy || !controller.hasLoaded ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save changes'),
              ),
            ],
          ),
        );
      },
    );
  }
}
