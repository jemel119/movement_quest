import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/training_summary.dart';
import '../repositories/training_log_repository.dart';
import '../services/training_summary_service.dart';

class TrainingSummaryPanel extends StatefulWidget {
  final TrainingSummaryService? service;

  const TrainingSummaryPanel({super.key, this.service});

  @override
  State<TrainingSummaryPanel> createState() => _TrainingSummaryPanelState();
}

class _TrainingSummaryPanelState extends State<TrainingSummaryPanel> {
  late final TrainingSummaryService _service;

  TrainingSummary? _summary;
  String? _error;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? TrainingSummaryService();
  }

  Future<void> _generate() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _summary = null;
      _error = null;
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
          onPressed: _loading ? null : _generate,
          icon: const Icon(Icons.summarize_outlined),
          label: Text(_loading ? 'Generating summary...' : 'Generate summary'),
        ),
        if (_loading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            semanticsLabel: 'Generating training summary',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, semanticsLabel: 'Error: $_error'),
        ],
        if (summary != null) ...[
          const SizedBox(height: 16),
          Text('Completed sessions: ${summary.completedSessions}'),
          Text('Unfinished sessions: ${summary.unfinishedSessions}'),
          Text('Total sets: ${summary.totalSets}'),
          Text('Total repetitions: ${summary.totalRepetitions}'),
          const SizedBox(height: 12),
          Text(
            'Generated: '
            '${summary.generatedAtUtc.toLocal().toString().split('.').first}',
          ),
          const SizedBox(height: 8),
          const Text(
            'Totals include completed and unfinished sessions. '
            'Generate again after changing your history.',
          ),
        ],
      ],
    );
  }
}
