import 'package:flutter/foundation.dart';

import '../models/training_session.dart';
import '../repositories/training_log_repository.dart';

class HistoryController extends ChangeNotifier {
  final TrainingLogRepository _repository;

  List<TrainingSession> _sessions = [];

  bool _hasLoaded = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _disposed = false;

  String? _error;

  HistoryController(this._repository);

  List<TrainingSession> get sessions => List.unmodifiable(_sessions);

  int get completedSessions =>
      _sessions.where((session) => session.sessionFinished).length;

  int get unfinishedSessions =>
      _sessions.where((session) => !session.sessionFinished).length;

  int get totalSets =>
      _sessions.fold(0, (total, session) => total + session.setCount);

  int get totalRepetitions =>
      _sessions.fold(0, (total, session) => total + session.totalRepetitions);

  bool get hasLoaded => _hasLoaded;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isBusy => _isLoading || _isSaving;

  String? get error => _error;

  Future<void> _refresh() async {
    final logs = await _repository.getLogs();
    final grouped = TrainingSession.groupLogs(logs);

    if (_disposed) return;

    _sessions = grouped;
    _hasLoaded = true;
  }

  Future<bool> load() async {
    if (_disposed || isBusy) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _refresh();
      return !_disposed;
    } catch (_) {
      if (!_disposed) {
        _error = 'Could not load your training history. Try again.';
      }

      return false;
    } finally {
      _isLoading = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<bool> editSet({
    required int logId,
    required String exerciseLabel,
    required int repetitions,
  }) async {
    if (!_canWrite) return false;

    final exercise = exerciseLabel.trim();

    if (exercise.isEmpty || repetitions <= 0) {
      _error = 'Enter an exercise and positive whole-number repetitions.';
      notifyListeners();
      return false;
    }

    if (!_containsLog(logId)) {
      _error = 'This set is no longer available. Refresh your history.';
      notifyListeners();
      return false;
    }

    return _write(
      () async {
        final existing = await _repository.getLog(logId);

        if (existing == null) {
          throw StateError('Set not found.');
        }

        await _repository.updateLog(
          existing.copyWith(exerciseLabel: exercise, repetitions: repetitions),
        );
      },
      failureMessage:
          'Could not update or refresh your set. Reload before retrying.',
    );
  }

  Future<bool> deleteSet(int logId) async {
    if (!_canWrite) return false;

    if (!_containsLog(logId)) {
      _error = 'This set is no longer available. Refresh your history.';
      notifyListeners();
      return false;
    }

    return _write(
      () => _repository.deleteLog(logId),
      failureMessage:
          'Could not delete or refresh your set. Reload before retrying.',
    );
  }

  Future<bool> renameSession({
    required String sessionKey,
    required String label,
  }) async {
    if (!_canWrite) return false;

    final trimmed = label.trim();

    if (trimmed.isEmpty) {
      _error = 'Enter a session label.';
      notifyListeners();
      return false;
    }

    TrainingSession? selected;

    for (final session in _sessions) {
      if (session.sessionKey == sessionKey) {
        selected = session;
        break;
      }
    }

    if (selected == null) {
      _error = 'This session is no longer available. Refresh your history.';
      notifyListeners();
      return false;
    }

    final workoutId = selected.workoutId;

    return _write(
      () async {
        final logs = await _repository.getLogs(workoutId: workoutId);
        final sessions = TrainingSession.groupLogs(logs);

        final current = sessions.firstWhere(
          (session) => session.sessionKey == sessionKey,
          orElse: () => throw StateError('Session not found.'),
        );

        await _repository.updateSession(
          workoutId: workoutId,
          sessionKey: sessionKey,
          sessionLabel: trimmed,
          sessionFinished: current.sessionFinished,
        );
      },
      failureMessage:
          'Could not rename or refresh your session. Reload before retrying.',
    );
  }

  bool _containsLog(int id) {
    return _sessions.any((session) => session.logs.any((log) => log.id == id));
  }

  bool get _canWrite => !_disposed && !isBusy && _hasLoaded;

  Future<bool> _write(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    if (!_canWrite) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await action();

      if (_disposed) return false;

      await _refresh();
      return !_disposed;
    } catch (_) {
      if (!_disposed) {
        _hasLoaded = false;
        _error = failureMessage;
      }

      return false;
    } finally {
      _isSaving = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
