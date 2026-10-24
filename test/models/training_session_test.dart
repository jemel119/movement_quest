import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/models/training_session.dart';

void main() {
  TrainingLog log({
    required int id,
    String key = 'session-a',
    String label = 'Morning session',
    int workoutId = 7,
    int repetitions = 8,
    int hour = 10,
    bool finished = true,
  }) {
    return TrainingLog(
      id: id,
      workoutId: workoutId,
      sessionKey: key,
      sessionLabel: label,
      exerciseLabel: 'Exercise $id',
      repetitions: repetitions,
      loggedAt: DateTime.utc(2026, 10, 24, hour),
      sessionFinished: finished,
    );
  }

  group('TrainingSession', () {
    test('Empty logs produce no sessions', () {
      expect(TrainingSession.groupLogs([]), isEmpty);
    });

    test('Three sets with one key produce one finished session', () {
      final sessions = TrainingSession.groupLogs([
        log(id: 1, repetitions: 8),
        log(id: 2, repetitions: 10),
        log(id: 3, repetitions: 12),
      ]);

      expect(sessions, hasLength(1));
      expect(sessions.single.sessionFinished, isTrue);
      expect(sessions.single.setCount, 3);
      expect(sessions.single.totalRepetitions, 30);
      expect(sessions.single.workoutId, 7);
      expect(sessions.single.sessionLabel, 'Morning session');
    });

    test('Sessions are ordered by their latest set timestamp', () {
      final sessions = TrainingSession.groupLogs([
        log(id: 1, key: 'older', hour: 8),
        log(id: 2, key: 'newer', hour: 9),
        log(id: 3, key: 'newer', hour: 12),
      ]);

      expect(sessions.map((session) => session.sessionKey).toList(), [
        'newer',
        'older',
      ]);
      expect(sessions.first.latestLoggedAt, DateTime.utc(2026, 10, 24, 12));
    });

    test('Equal timestamps use ascending session keys', () {
      final sessions = TrainingSession.groupLogs([
        log(id: 1, key: 'session-b'),
        log(id: 2, key: 'session-a'),
      ]);

      expect(sessions.map((session) => session.sessionKey).toList(), [
        'session-a',
        'session-b',
      ]);
    });

    test('Finished and unfinished sessions remain distinguishable', () {
      final sessions = TrainingSession.groupLogs([
        log(id: 1, key: 'finished'),
        log(id: 2, key: 'unfinished', finished: false),
      ]);

      expect(
        sessions.where((session) => session.sessionFinished),
        hasLength(1),
      );
      expect(
        sessions.where((session) => !session.sessionFinished),
        hasLength(1),
      );
    });

    test('Deleting sets changes totals without splitting the session', () {
      final rows = [log(id: 1), log(id: 2), log(id: 3)];

      expect(TrainingSession.groupLogs(rows), hasLength(1));

      rows.removeLast();

      final remaining = TrainingSession.groupLogs(rows);

      expect(remaining, hasLength(1));
      expect(remaining.single.setCount, 2);

      rows.clear();

      expect(TrainingSession.groupLogs(rows), isEmpty);
    });

    test('Inconsistent session metadata is rejected', () {
      final conflictingRows = [
        log(id: 2, workoutId: 8),
        log(id: 2, label: 'Different label'),
        log(id: 2, finished: false),
      ];

      for (final conflicting in conflictingRows) {
        expect(
          () => TrainingSession.groupLogs([log(id: 1), conflicting]),
          throwsStateError,
        );
      }
    });

    test('Session logs cannot be modified through the grouped result', () {
      final rows = [log(id: 1)];
      final sessions = TrainingSession.groupLogs(rows);

      rows.clear();

      expect(sessions.single.logs, hasLength(1));
      expect(() => sessions.single.logs.clear(), throwsUnsupportedError);
      expect(() => sessions.clear(), throwsUnsupportedError);
    });
  });
}
