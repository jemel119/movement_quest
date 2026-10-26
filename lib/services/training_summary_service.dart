import 'dart:isolate';

import '../models/training_log.dart';
import '../models/training_session.dart';
import '../models/training_summary.dart';

class TrainingSummaryService {
  Future<TrainingSummary> generate(List<TrainingLog> logs) async {
    final payload = logs.map((log) => log.toMap()).toList();

    final result = await Isolate.run(() => _calculateSummary(payload));

    return TrainingSummary.fromMap(result);
  }
}

Map<String, Object?> _calculateSummary(List<Map<String, Object?>> payload) {
  final logs = payload.map(TrainingLog.fromMap).toList();
  final sessions = TrainingSession.groupLogs(logs);

  final summary = TrainingSummary(
    generatedAtUtc: DateTime.now().toUtc(),
    completedSessions: sessions
        .where((session) => session.sessionFinished)
        .length,
    unfinishedSessions: sessions
        .where((session) => !session.sessionFinished)
        .length,
    totalSets: sessions.fold<int>(
      0,
      (total, session) => total + session.setCount,
    ),
    totalRepetitions: sessions.fold<int>(
      0,
      (total, session) => total + session.totalRepetitions,
    ),
  );

  return summary.toMap();
}
