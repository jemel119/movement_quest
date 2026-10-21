import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/training_log.dart';

void main() {
  final timestamp = DateTime.utc(2026, 10, 20, 14, 30);

  TrainingLog makeLog({
    int? id,
    int workoutId = 7,
    String sessionKey = 'session-001',
    String sessionLabel = 'Morning session',
    String exerciseLabel = 'Example exercise',
    int repetitions = 8,
    DateTime? loggedAt,
    bool sessionFinished = false,
  }) {
    return TrainingLog(
      id: id,
      workoutId: workoutId,
      sessionKey: sessionKey,
      sessionLabel: sessionLabel,
      exerciseLabel: exerciseLabel,
      repetitions: repetitions,
      loggedAt: loggedAt ?? timestamp,
      sessionFinished: sessionFinished,
    );
  }

  group('TrainingLog', () {
    test('Trims labels and omits an unsaved ID', () {
      final log = makeLog(
        sessionKey: '  session-001  ',
        sessionLabel: '  Morning session  ',
        exerciseLabel: '  Example exercise  ',
      );

      expect(log.sessionKey, 'session-001');
      expect(log.sessionLabel, 'Morning session');
      expect(log.exerciseLabel, 'Example exercise');
      expect(log.sessionFinished, isFalse);
      expect(log.toMap().containsKey('id'), isFalse);
    });

    test('Rejects nonpositive workout IDs', () {
      for (final value in [0, -1]) {
        expect(() => makeLog(workoutId: value), throwsArgumentError);
      }
    });

    test('Rejects missing session keys and blank labels', () {
      expect(() => makeLog(sessionKey: ' '), throwsArgumentError);
      expect(() => makeLog(sessionLabel: ' '), throwsArgumentError);
      expect(() => makeLog(exerciseLabel: ' '), throwsArgumentError);
    });

    test('Accepts one repetition and rejects nonpositive values', () {
      expect(makeLog(repetitions: 1).repetitions, 1);

      for (final value in [0, -1]) {
        expect(() => makeLog(repetitions: value), throwsArgumentError);
      }
    });

    test('Rejects nonpositive saved log IDs', () {
      for (final value in [0, -1]) {
        expect(() => makeLog(id: value), throwsArgumentError);
      }
    });

    test('Normalizes timestamps to UTC without changing the instant', () {
      final input = DateTime.parse('2026-10-20T10:30:00-04:00');
      final log = makeLog(loggedAt: input);

      expect(log.loggedAt.isUtc, isTrue);
      expect(log.loggedAt, timestamp);
      expect(log.toMap()['loggedAt'], '2026-10-20T14:30:00.000Z');
    });

    test('Maps finish status to SQLite integers', () {
      expect(makeLog().toMap()['sessionFinished'], 0);
      expect(makeLog(sessionFinished: true).toMap()['sessionFinished'], 1);
    });

    test('Reconstructs a saved database row', () {
      final log = TrainingLog.fromMap({
        'id': 12,
        'workoutId': 7,
        'sessionKey': 'session-001',
        'sessionLabel': 'Morning session',
        'exerciseLabel': 'Example exercise',
        'repetitions': 8,
        'loggedAt': '2026-10-20T14:30:00.000Z',
        'sessionFinished': 1,
      });

      expect(log.id, 12);
      expect(log.workoutId, 7);
      expect(log.sessionKey, 'session-001');
      expect(log.sessionLabel, 'Morning session');
      expect(log.exerciseLabel, 'Example exercise');
      expect(log.repetitions, 8);
      expect(log.loggedAt, timestamp);
      expect(log.sessionFinished, isTrue);
    });

    test('Rejects invalid stored finish status', () {
      final row = makeLog().toMap();

      for (final value in <Object?>[2, -1, '1', null]) {
        expect(
          () => TrainingLog.fromMap({...row, 'sessionFinished': value}),
          throwsFormatException,
        );
      }
    });

    test('Corrects a set while preserving its identity and timestamp', () {
      final original = makeLog(id: 12);
      final updated = original.copyWith(
        exerciseLabel: 'Corrected exercise',
        repetitions: 10,
      );

      expect(updated.id, original.id);
      expect(updated.workoutId, original.workoutId);
      expect(updated.sessionKey, original.sessionKey);
      expect(updated.loggedAt, original.loggedAt);
      expect(updated.sessionLabel, original.sessionLabel);
      expect(updated.exerciseLabel, 'Corrected exercise');
      expect(updated.repetitions, 10);
      expect(original.exerciseLabel, 'Example exercise');
      expect(original.repetitions, 8);
    });

    test('Validates changes made through copyWith', () {
      final log = makeLog(id: 12);

      expect(() => log.copyWith(repetitions: 0), throwsArgumentError);
      expect(() => log.copyWith(sessionLabel: ' '), throwsArgumentError);
    });
  });
}
