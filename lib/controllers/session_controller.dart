import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/training_log.dart';
import '../repositories/training_log_repository.dart';

class SessionController extends ChangeNotifier {
  final TrainingLogRepository _repository;
  final int workoutId;

  List<TrainingLog> _logs = [];

  String? _sessionKey;
  String? _sessionLabel;
  String? _error;

  bool _hasLoaded = false;
  bool _isBusy = false;
  bool _disposed = false;

  SessionController(this._repository, {required this.workoutId}) {
    if (workoutId <= 0) {
      throw ArgumentError('Workout ID must be positive.');
    }
  }

  List<TrainingLog> get logs => List.unmodifiable(_logs);

  List<TrainingLog> get sessionLogs =>
      List.unmodifiable(_logs.where((log) => log.sessionKey == _sessionKey));

  String? get sessionKey => _sessionKey;

  String? get sessionLabel => _sessionLabel;

  String? get error => _error;

  bool get hasLoaded => _hasLoaded;

  bool get isBusy => _isBusy;

  bool get hasActiveSession => _sessionKey != null;

  Future<void> _refresh() async {
    final loaded = await _repository.getLogs(workoutId: workoutId);

    if (_disposed) return;

    final unfinished = loaded.where((log) => !log.sessionFinished);
    final keys = unfinished.map((log) => log.sessionKey).toSet();

    if (keys.length > 1) {
      throw StateError(
        'More than one unfinished session exists for this workout.',
      );
    }

    if (unfinished.isNotEmpty) {
      final first = unfinished.first;

      if (unfinished.any((log) => log.sessionLabel != first.sessionLabel)) {
        throw StateError('The saved session labels are inconsistent.');
      }

      _sessionKey = first.sessionKey;
      _sessionLabel = first.sessionLabel;
    }

    _logs = loaded;
    _hasLoaded = true;
  }

  Future<bool> load() async {
    if (_disposed || _isBusy) return false;

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      await _refresh();
      return !_disposed;
    } catch (_) {
      if (!_disposed) {
        _hasLoaded = false;
        _error = 'Could not load your session. Try again.';
      }

      return false;
    } finally {
      _isBusy = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  bool startSession(String label) {
    if (_disposed || _isBusy || !_hasLoaded || hasActiveSession) {
      return false;
    }

    final trimmed = label.trim();

    if (trimmed.isEmpty) {
      _error = 'Enter a session label.';
      notifyListeners();
      return false;
    }

    final random = Random.secure();
    final suffix = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();

    _sessionKey =
        '${workoutId}_${DateTime.now().toUtc().microsecondsSinceEpoch}_$suffix';
    _sessionLabel = trimmed;
    _error = null;

    notifyListeners();
    return true;
  }

  Future<bool> addSet({
    required String exerciseLabel,
    required int repetitions,
  }) async {
    if (!_canChangeSession) return false;

    final exercise = exerciseLabel.trim();

    if (exercise.isEmpty || repetitions <= 0) {
      _error = 'Enter an exercise and positive whole-number repetitions.';
      notifyListeners();
      return false;
    }

    final log = TrainingLog(
      workoutId: workoutId,
      sessionKey: _sessionKey!,
      sessionLabel: _sessionLabel!,
      exerciseLabel: exercise,
      repetitions: repetitions,
      loggedAt: DateTime.now().toUtc(),
    );

    return _write(
      () async {
        await _repository.createLog(log);
      },
      failureMessage:
          'Could not save or refresh your set. Reload before retrying.',
    );
  }

  Future<bool> finishSession() async {
    if (!_canChangeSession) return false;

    if (sessionLogs.isEmpty) {
      _error = 'Log at least one set before finishing the session.';
      notifyListeners();
      return false;
    }

    final key = _sessionKey!;
    final label = _sessionLabel!;

    return _write(
      () async {
        await _repository.updateSession(
          workoutId: workoutId,
          sessionKey: key,
          sessionLabel: label,
          sessionFinished: true,
        );

        if (!_disposed) {
          _sessionKey = null;
          _sessionLabel = null;
        }
      },
      failureMessage:
          'Could not finish or refresh your session. Reload before retrying.',
    );
  }

  Future<bool> resetSession() async {
    if (!_canChangeSession) return false;

    final key = _sessionKey!;

    return _write(
      () async {
        await _repository.deleteUnfinishedSession(
          workoutId: workoutId,
          sessionKey: key,
        );

        if (!_disposed) {
          _sessionKey = null;
          _sessionLabel = null;
        }
      },
      failureMessage:
          'Could not reset or refresh your session. Reload before retrying.',
    );
  }

  bool get _canChangeSession =>
      !_disposed && !_isBusy && _hasLoaded && hasActiveSession;

  Future<bool> _write(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    if (!_canChangeSession) return false;

    _isBusy = true;
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
      _isBusy = false;

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
