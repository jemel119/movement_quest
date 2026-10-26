import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/history_controller.dart';
import '../models/training_log.dart';
import '../repositories/training_log_repository.dart';
import '../widgets/history_editor_dialog.dart';
import 'workout_detail_screen.dart';
import '../widgets/training_summary_panel.dart';

class HistoryScreen extends StatefulWidget {
  final bool isActive;

  const HistoryScreen({super.key, this.isActive = true});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryController _controller;

  bool _openingWorkout = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();

    _controller = HistoryController(context.read<TrainingLogRepository>());

    if (widget.isActive) {
      _controller.load();
    }
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      _controller.load();
    }
  }

  Future<void> _openWorkout(int workoutId) async {
    if (_openingWorkout || _dialogOpen || _controller.isBusy) return;

    setState(() => _openingWorkout = true);

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WorkoutDetailScreen(workoutId: workoutId),
        ),
      );

      if (!mounted) return;

      await _controller.load();
    } finally {
      if (mounted) {
        setState(() => _openingWorkout = false);
      }
    }
  }

  Future<void> _openEditor(Widget dialog) async {
    if (_dialogOpen || _openingWorkout || _controller.isBusy) {
      return;
    }

    setState(() => _dialogOpen = true);

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => dialog,
      );
    } finally {
      if (mounted) {
        setState(() => _dialogOpen = false);
      }
    }
  }

  Future<void> _deleteSet(TrainingLog log) async {
    if (_dialogOpen || _openingWorkout || _controller.isBusy) {
      return;
    }

    final id = log.id;
    if (id == null) return;

    setState(() => _dialogOpen = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete saved set?'),
          content: Text(
            'Delete "${log.exerciseLabel}" '
            'with ${log.repetitions} repetitions? '
            'If this is the final set, its session will disappear '
            'from history.',
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

      await _controller.deleteSet(id);
    } finally {
      if (mounted) {
        setState(() => _dialogOpen = false);
      }
    }
  }

  Future<void> _openSummary() {
    return _openEditor(
      AlertDialog(
        title: const Text('Training summary'),
        content: const SingleChildScrollView(
          child: SizedBox(width: 400, child: TrainingSummaryPanel()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final busy = _controller.isBusy || _openingWorkout || _dialogOpen;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Session history',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Training summary',
                        onPressed: busy ? null : _openSummary,
                        icon: const Icon(Icons.summarize_outlined),
                      ),
                      IconButton(
                        tooltip: 'Refresh history',
                        onPressed: busy ? null : _controller.load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  Text('Completed sessions: ${_controller.completedSessions}'),
                  Text(
                    'Unfinished sessions: ${_controller.unfinishedSessions}',
                  ),
                  Text('Total sets: ${_controller.totalSets}'),
                  Text('Total repetitions: ${_controller.totalRepetitions}'),
                  const SizedBox(height: 8),
                  const Text(
                    'Set and repetition totals include completed '
                    'and unfinished sessions.',
                  ),
                  if (_controller.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _controller.error!,
                      semanticsLabel: 'Error: ${_controller.error}',
                    ),
                    TextButton(
                      onPressed: busy ? null : _controller.load,
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
            if (_controller.isBusy)
              const LinearProgressIndicator(
                semanticsLabel: 'Updating training history',
              ),
            Expanded(
              child: !_controller.hasLoaded
                  ? Center(
                      child: Text(
                        _controller.isLoading
                            ? 'Loading your training history...'
                            : 'Your training history could not be loaded.',
                      ),
                    )
                  : _controller.sessions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No training history yet.'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: _controller.sessions.length,
                      itemBuilder: (context, index) {
                        final session = _controller.sessions[index];
                        final latest = session.latestLoggedAt
                            .toLocal()
                            .toString()
                            .split('.')
                            .first;

                        return Card(
                          child: ExpansionTile(
                            key: PageStorageKey(session.sessionKey),
                            title: Text(session.sessionLabel),
                            subtitle: Text(
                              '${session.sessionFinished ? 'Completed' : 'Unfinished'}'
                              ' · ${session.setCount} sets\n'
                              'Latest set: $latest',
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Session repetitions: '
                                    '${session.totalRepetitions}',
                                  ),
                                ),
                              ),
                              ...session.logs.map(
                                (log) => Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(log.exerciseLabel),
                                      Text('${log.repetitions} repetitions'),
                                      Wrap(
                                        alignment: WrapAlignment.end,
                                        spacing: 8,
                                        children: [
                                          TextButton(
                                            onPressed: busy
                                                ? null
                                                : () => _openEditor(
                                                    HistoryEditorDialog.editSet(
                                                      controller: _controller,
                                                      log: log,
                                                    ),
                                                  ),
                                            child: const Text('Edit set'),
                                          ),
                                          TextButton(
                                            onPressed: busy
                                                ? null
                                                : () => _deleteSet(log),
                                            child: const Text('Delete set'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () =>
                                                _openWorkout(session.workoutId),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      label: const Text('View workout'),
                                    ),
                                    TextButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => _openEditor(
                                              HistoryEditorDialog.renameSession(
                                                controller: _controller,
                                                session: session,
                                              ),
                                            ),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Rename session'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
