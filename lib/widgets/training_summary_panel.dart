import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/local_summary_file_repository.dart';
import '../models/training_summary.dart';
import '../repositories/summary_file_repository.dart';
import '../repositories/training_log_repository.dart';
import '../services/training_summary_service.dart';
import 'animated_summary_totals.dart';

class TrainingSummaryPanel extends StatefulWidget {
  final TrainingSummaryService? service;
  final SummaryFileRepository? fileRepository;

  const TrainingSummaryPanel({super.key, this.service, this.fileRepository});

  @override
  State<TrainingSummaryPanel> createState() => _TrainingSummaryPanelState();
}

class _TrainingSummaryPanelState extends State<TrainingSummaryPanel> {
  late final TrainingSummaryService _service;
  late final SummaryFileRepository _fileRepository;

  TrainingSummary? _summary;

  String? _error;
  String? _message;

  bool _loading = false;
  bool _saving = false;
  bool _reading = false;
  bool _showingSavedSummary = false;

  bool get _busy => _loading || _saving || _reading;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? TrainingSummaryService();
    _fileRepository = widget.fileRepository ?? LocalSummaryFileRepository();
  }

  Future<void> _generate() async {
    if (_busy) return;

    setState(() {
      _loading = true;
      _summary = null;
      _error = null;
      _message = null;
      _showingSavedSummary = false;
    });

    try {
      final repository = context.read<TrainingLogRepository>();
      final logs = await repository.getLogs();

      if (!mounted) return;

      final summary = await _service.generate(logs);

      if (!mounted) return;

      setState(() => _summary = summary);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not generate your training summary. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final summary = _summary;

    if (_busy || summary == null) return;

    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });

    try {
      await _fileRepository.save(summary);

      if (!mounted) return;

      setState(() {
        _message = 'Summary saved on this device.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not save your summary file. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _read() async {
    if (_busy) return;

    setState(() {
      _reading = true;
      _error = null;
      _message = null;
    });

    try {
      final summary = await _fileRepository.read();

      if (!mounted) return;

      setState(() {
        if (summary == null) {
          _message = 'No saved summary found. Generate and save one first.';
        } else {
          _summary = summary;
          _showingSavedSummary = true;
          _message = 'Saved summary loaded.';
        }
      });
    } on FormatException {
      if (!mounted) return;

      setState(() {
        _error =
            'The saved summary is invalid or uses an unsupported version. '
            'Generate a new summary and save it to replace the file.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not read your summary file. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _reading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Generate a snapshot of your saved training history. '
          'Summary calculations run in a separate Dart isolate.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _generate,
          icon: const Icon(Icons.summarize_outlined),
          label: Text(_loading ? 'Generating summary...' : 'Generate summary'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _read,
          icon: const Icon(Icons.folder_open),
          label: Text(_reading ? 'Reading summary...' : 'Read saved summary'),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            semanticsLabel: _loading
                ? 'Generating training summary'
                : _saving
                ? 'Saving training summary'
                : 'Reading training summary',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, semanticsLabel: 'Error: $_error'),
        ],
        if (_message != null) ...[const SizedBox(height: 16), Text(_message!)],
        if (summary != null) ...[
          const SizedBox(height: 16),
          AnimatedSummaryTotals(
            summary: summary,
            isSaved: _showingSavedSummary,
          ),
          const SizedBox(height: 12),
          Text(
            'Generated: '
            '${summary.generatedAtUtc.toLocal().toString().split('.').first}',
          ),
          const SizedBox(height: 8),
          const Text(
            'Totals include completed and unfinished sessions. '
            'A saved snapshot may differ from your current history.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving summary...' : 'Save summary'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Saving replaces the previous summary file. '
            'Reading a summary does not change workout records.',
          ),
        ],
      ],
    );
  }
}
