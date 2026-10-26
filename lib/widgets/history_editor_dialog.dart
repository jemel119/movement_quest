import 'package:flutter/material.dart';

import '../controllers/history_controller.dart';
import '../models/training_log.dart';
import '../models/training_session.dart';

class HistoryEditorDialog extends StatefulWidget {
  final HistoryController controller;
  final TrainingLog? log;
  final TrainingSession? session;

  const HistoryEditorDialog.editSet({
    super.key,
    required this.controller,
    required TrainingLog this.log,
  }) : session = null;

  const HistoryEditorDialog.renameSession({
    super.key,
    required this.controller,
    required TrainingSession this.session,
  }) : log = null;

  @override
  State<HistoryEditorDialog> createState() => _HistoryEditorDialogState();
}

class _HistoryEditorDialogState extends State<HistoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _labelController;
  late final TextEditingController _repetitionsController;

  bool _saving = false;

  bool get _editingSet => widget.log != null;

  @override
  void initState() {
    super.initState();

    _labelController = TextEditingController(
      text: widget.log?.exerciseLabel ?? widget.session!.sessionLabel,
    );
    _repetitionsController = TextEditingController(
      text: widget.log?.repetitions.toString() ?? '',
    );
  }

  Future<void> _save() async {
    final controller = widget.controller;

    if (_saving || controller.isBusy || !controller.hasLoaded) {
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    final bool saved;

    if (_editingSet) {
      final id = widget.log!.id;

      if (id == null) {
        setState(() => _saving = false);
        return;
      }

      saved = await controller.editSet(
        logId: id,
        exerciseLabel: _labelController.text,
        repetitions: int.parse(_repetitionsController.text.trim()),
      );
    } else {
      saved = await controller.renameSession(
        sessionKey: widget.session!.sessionKey,
        label: _labelController.text,
      );
    }

    if (!mounted) return;

    if (saved) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = false);
  }

  @override
  void dispose() {
    _labelController.dispose();
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
            title: Text(_editingSet ? 'Edit set' : 'Rename session'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _labelController,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: _editingSet
                            ? 'Exercise label'
                            : 'Session label',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return _editingSet
                              ? 'Enter an exercise label.'
                              : 'Enter a session label.';
                        }

                        return null;
                      },
                    ),
                    if (_editingSet) ...[
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
                    ],
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
                        child: const Text('Reload history'),
                      ),
                    ],
                    if (busy) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(
                        semanticsLabel: 'Saving history changes',
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
