import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/models/training_summary.dart';
import 'package:movement_quest/services/training_summary_service.dart';

void main() {
  final service = TrainingSummaryService();

  TrainingLog log({
    required int id,
    String key = 'finished-session',
    int repetitions = 8,
    bool finished = true,
  }) {
    return TrainingLog(
      id: id,
      workoutId: 7,
      sessionKey: key,
      sessionLabel: key,
      exerciseLabel: 'Exercise $id',
      repetitions: repetitions,
      loggedAt: DateTime.utc(2026, 10, 25, 10),
      sessionFinished: finished,
    );
  }

  test('Empty data produces a zero summary', () async {
    final summary = await service.generate([]);

    expect(summary.completedSessions, 0);
    expect(summary.unfinishedSessions, 0);
    expect(summary.totalSets, 0);
    expect(summary.totalRepetitions, 0);
    expect(summary.generatedAtUtc.isUtc, isTrue);
  });

  test('The isolate groups sessions and calculates set totals', () async {
    final summary = await service.generate([
      log(id: 1, repetitions: 8),
      log(id: 2, repetitions: 10),
      log(id: 3, repetitions: 12),
      log(id: 4, key: 'unfinished-session', repetitions: 5, finished: false),
    ]);

    expect(summary.completedSessions, 1);
    expect(summary.unfinishedSessions, 1);
    expect(summary.totalSets, 4);
    expect(summary.totalRepetitions, 35);
  });

  test('Inconsistent session data produces an error', () async {
    await expectLater(
      service.generate([log(id: 1), log(id: 2, finished: false)]),
      throwsStateError,
    );
  });

  test('A summary survives versioned map serialization', () async {
    final summary = await service.generate([log(id: 1, repetitions: 12)]);

    final restored = TrainingSummary.fromMap(summary.toMap());

    expect(restored.generatedAtUtc, summary.generatedAtUtc);
    expect(restored.completedSessions, 1);
    expect(restored.unfinishedSessions, 0);
    expect(restored.totalSets, 1);
    expect(restored.totalRepetitions, 12);
  });

  test('Unsupported versions and invalid totals are rejected', () {
    final valid = TrainingSummary(
      generatedAtUtc: DateTime.utc(2026, 10, 25),
      completedSessions: 1,
      unfinishedSessions: 0,
      totalSets: 2,
      totalRepetitions: 16,
    ).toMap();

    final invalidMaps = [
      {...valid, 'version': 2},
      {...valid, 'completedSessions': -1},
      {...valid, 'completedSessions': 3},
      {...valid, 'totalRepetitions': 1},
      {...valid, 'totalSets': '2'},
      {...valid, 'generatedAtUtc': 'invalid'},
    ];

    for (final map in invalidMaps) {
      expect(
        () => TrainingSummary.fromMap(map),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
