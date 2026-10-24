import 'training_log.dart';

class TrainingSession {
  final int workoutId;
  final String sessionKey;
  final String sessionLabel;
  final bool sessionFinished;
  final List<TrainingLog> logs;

  TrainingSession._({
    required this.workoutId,
    required this.sessionKey,
    required this.sessionLabel,
    required this.sessionFinished,
    required List<TrainingLog> logs,
  }) : logs = List.unmodifiable(logs);

  DateTime get latestLoggedAt => logs
      .map((log) => log.loggedAt)
      .reduce((latest, time) => time.isAfter(latest) ? time : latest);

  int get setCount => logs.length;

  int get totalRepetitions =>
      logs.fold(0, (total, log) => total + log.repetitions);

  static List<TrainingSession> groupLogs(List<TrainingLog> logs) {
    final groups = <String, List<TrainingLog>>{};

    for (final log in logs) {
      groups.putIfAbsent(log.sessionKey, () => []).add(log);
    }

    final sessions = <TrainingSession>[];

    for (final entry in groups.entries) {
      final rows = entry.value;
      final first = rows.first;

      if (rows.any(
        (log) =>
            log.workoutId != first.workoutId ||
            log.sessionLabel != first.sessionLabel ||
            log.sessionFinished != first.sessionFinished,
      )) {
        throw StateError('Session metadata is inconsistent.');
      }

      rows.sort((a, b) {
        final timeOrder = a.loggedAt.compareTo(b.loggedAt);

        if (timeOrder != 0) return timeOrder;

        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

      sessions.add(
        TrainingSession._(
          workoutId: first.workoutId,
          sessionKey: entry.key,
          sessionLabel: first.sessionLabel,
          sessionFinished: first.sessionFinished,
          logs: rows,
        ),
      );
    }

    sessions.sort((a, b) {
      final timeOrder = b.latestLoggedAt.compareTo(a.latestLoggedAt);

      if (timeOrder != 0) return timeOrder;

      return a.sessionKey.compareTo(b.sessionKey);
    });

    return List.unmodifiable(sessions);
  }
}
