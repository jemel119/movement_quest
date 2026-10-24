import 'package:flutter/foundation.dart';

import '../models/training_session.dart';
import '../repositories/training_log_repository.dart';

class HistoryController extends ChangeNotifier {
  final TrainingLogRepository _repository;

  List<TrainingSession> _sessions = [];

  bool _hasLoaded = false;
  bool _isLoading = false;
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

  String? get error => _error;

  Future<bool> load() async {
    if (_disposed || _isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final logs = await _repository.getLogs();
      final grouped = TrainingSession.groupLogs(logs);

      if (_disposed) return false;

      _sessions = grouped;
      _hasLoaded = true;

      return true;
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
