import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/history_controller.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';

class HistoryEditingRepository extends Fake implements TrainingLogRepository {
  final List<TrainingLog> records;

  bool failWrites = false;
  bool failReads = false;
  bool failReadsAfterWrite = false;

  int updateCalls = 0;
  int deleteCalls = 0;
  int renameCalls = 0;

  HistoryEditingRepository(this.records);

  void _checkWrite() {
    if (failWrites) {
      throw Exception('Write failed.');
    }
  }

  void _afterWrite() {
    if (failReadsAfterWrite) {
      failReads = true;
    }
  }

  @override
  Future<List<TrainingLog>> getLogs({int? workoutId}) async {
    if (failReads) {
      throw Exception('Read failed.');
    }

    return records
        .where((log) => workoutId == null || log.workoutId == workoutId)
        .toList();
  }

  @override
  Future<TrainingLog?> getLog(int id) async {
    if (failReads) {
      throw Exception('Read failed.');
    }

    for (final log in records) {
      if (log.id == id) return log;
    }

    return null;
  }

  @override
  Future<TrainingLog> updateLog(TrainingLog log) async {
    updateCalls++;
    _checkWrite();

    final index = records.indexWhere((record) => record.id == log.id);

    if (index == -1) {
      throw StateError('Set not found.');
    }

    records[index] = log;
    _afterWrite();

    return log;
  }

  @override
  Future<void> deleteLog(int id) async {
    deleteCalls++;
    _checkWrite();

    final index = records.indexWhere((log) => log.id == id);

    if (index == -1) {
      throw StateError('Set not found.');
    }

    records.removeAt(index);
    _afterWrite();
  }

  @override
  Future<void> updateSession({
    required int workoutId,
    required String sessionKey,
    required String sessionLabel,
    required bool sessionFinished,
  }) async {
    renameCalls++;
    _checkWrite();

    var changed = false;

    for (var index = 0; index < records.length; index++) {
      final log = records[index];

      if (log.workoutId == workoutId && log.sessionKey == sessionKey) {
        records[index] = log.copyWith(
          sessionLabel: sessionLabel,
          sessionFinished: sessionFinished,
        );
        changed = true;
      }
    }

    if (!changed) {
      throw StateError('Session not found.');
    }

    _afterWrite();
  }
}

void main() {
  TrainingLog log({
    required int id,
    String key = 'completed-session',
    bool finished = true,
    int repetitions = 8,
  }) {
    return TrainingLog(
      id: id,
      workoutId: 7,
      sessionKey: key,
      sessionLabel: 'Original label',
      exerciseLabel: 'Exercise $id',
      repetitions: repetitions,
      loggedAt: DateTime.utc(2026, 10, 25, 10),
      sessionFinished: finished,
    );
  }

  Future<HistoryController> loadController(
    HistoryEditingRepository repository,
  ) async {
    final controller = HistoryController(repository);

    addTearDown(controller.dispose);

    expect(await controller.load(), isTrue);

    return controller;
  }

  group('History editing', () {
    test(
      'Editing a completed set preserves its identity and metadata',
      () async {
        final original = log(id: 1);
        final repository = HistoryEditingRepository([original]);
        final controller = await loadController(repository);

        expect(
          await controller.editSet(
            logId: 1,
            exerciseLabel: ' Updated exercise ',
            repetitions: 15,
          ),
          isTrue,
        );

        final updated = repository.records.single;

        expect(repository.updateCalls, 1);
        expect(updated.id, original.id);
        expect(updated.workoutId, original.workoutId);
        expect(updated.sessionKey, original.sessionKey);
        expect(updated.sessionLabel, original.sessionLabel);
        expect(updated.loggedAt, original.loggedAt);
        expect(updated.sessionFinished, isTrue);
        expect(updated.exerciseLabel, 'Updated exercise');
        expect(updated.repetitions, 15);
        expect(controller.completedSessions, 1);
        expect(controller.totalRepetitions, 15);
      },
    );

    test('Invalid edits are rejected before writing', () async {
      final repository = HistoryEditingRepository([log(id: 1)]);
      final controller = await loadController(repository);

      expect(
        await controller.editSet(logId: 1, exerciseLabel: ' ', repetitions: 8),
        isFalse,
      );

      for (final repetitions in [0, -1]) {
        expect(
          await controller.editSet(
            logId: 1,
            exerciseLabel: 'My exercise',
            repetitions: repetitions,
          ),
          isFalse,
        );
      }

      expect(repository.updateCalls, 0);
      expect(repository.records.single.repetitions, 8);
    });

    test(
      'Deleting sets keeps the session until its final set is removed',
      () async {
        final repository = HistoryEditingRepository([log(id: 1), log(id: 2)]);
        final controller = await loadController(repository);

        expect(await controller.deleteSet(1), isTrue);
        expect(controller.completedSessions, 1);
        expect(controller.totalSets, 1);

        expect(await controller.deleteSet(2), isTrue);
        expect(controller.completedSessions, 0);
        expect(controller.totalSets, 0);
        expect(controller.totalRepetitions, 0);
        expect(controller.sessions, isEmpty);
        expect(repository.deleteCalls, 2);
      },
    );

    test(
      'Renaming updates every set and preserves completion status',
      () async {
        final originals = [log(id: 1), log(id: 2)];
        final repository = HistoryEditingRepository(List.of(originals));
        final controller = await loadController(repository);

        expect(
          await controller.renameSession(
            sessionKey: 'completed-session',
            label: ' Renamed session ',
          ),
          isTrue,
        );

        expect(repository.renameCalls, 1);
        expect(repository.records, hasLength(2));

        for (var index = 0; index < originals.length; index++) {
          final original = originals[index];
          final updated = repository.records[index];

          expect(updated.id, original.id);
          expect(updated.workoutId, original.workoutId);
          expect(updated.sessionKey, original.sessionKey);
          expect(updated.loggedAt, original.loggedAt);
          expect(updated.repetitions, original.repetitions);
          expect(updated.exerciseLabel, original.exerciseLabel);
          expect(updated.sessionFinished, isTrue);
          expect(updated.sessionLabel, 'Renamed session');
        }

        expect(controller.sessions.single.sessionLabel, 'Renamed session');
        expect(controller.completedSessions, 1);
      },
    );

    test('Renaming an unfinished session does not finish it', () async {
      final repository = HistoryEditingRepository([
        log(id: 1, finished: false),
      ]);
      final controller = await loadController(repository);

      expect(
        await controller.renameSession(
          sessionKey: 'completed-session',
          label: 'Still unfinished',
        ),
        isTrue,
      );

      expect(repository.records.single.sessionFinished, isFalse);
      expect(controller.completedSessions, 0);
      expect(controller.unfinishedSessions, 1);
    });

    test('Blank session labels are rejected without writing', () async {
      final repository = HistoryEditingRepository([log(id: 1)]);
      final controller = await loadController(repository);

      expect(
        await controller.renameSession(
          sessionKey: 'completed-session',
          label: '   ',
        ),
        isFalse,
      );

      expect(repository.renameCalls, 0);
      expect(controller.error, 'Enter a session label.');
    });

    test('Unknown sets and sessions cannot be changed', () async {
      final repository = HistoryEditingRepository([log(id: 1)]);
      final controller = await loadController(repository);

      expect(
        await controller.editSet(
          logId: 99,
          exerciseLabel: 'Unknown exercise',
          repetitions: 8,
        ),
        isFalse,
      );
      expect(await controller.deleteSet(99), isFalse);
      expect(
        await controller.renameSession(
          sessionKey: 'missing-session',
          label: 'New label',
        ),
        isFalse,
      );

      expect(repository.updateCalls, 0);
      expect(repository.deleteCalls, 0);
      expect(repository.renameCalls, 0);
    });

    test('A failed write blocks further edits until reload', () async {
      final repository = HistoryEditingRepository([log(id: 1)]);
      final controller = await loadController(repository);

      repository.failWrites = true;

      expect(
        await controller.editSet(
          logId: 1,
          exerciseLabel: 'Updated exercise',
          repetitions: 12,
        ),
        isFalse,
      );

      expect(controller.hasLoaded, isFalse);
      expect(controller.error, isNotNull);
      expect(controller.isBusy, isFalse);
      expect(repository.records.single.repetitions, 8);

      expect(await controller.deleteSet(1), isFalse);
      expect(repository.deleteCalls, 0);

      repository.failWrites = false;

      expect(await controller.load(), isTrue);
      expect(controller.error, isNull);

      expect(
        await controller.editSet(
          logId: 1,
          exerciseLabel: 'Updated exercise',
          repetitions: 12,
        ),
        isTrue,
      );

      expect(repository.records.single.repetitions, 12);
    });

    test('Reload recovers after deletion succeeds but refresh fails', () async {
      final repository = HistoryEditingRepository([log(id: 1), log(id: 2)]);
      final controller = await loadController(repository);

      repository.failReadsAfterWrite = true;

      expect(await controller.deleteSet(1), isFalse);

      expect(repository.records, hasLength(1));
      expect(repository.records.single.id, 2);
      expect(controller.hasLoaded, isFalse);
      expect(repository.deleteCalls, 1);

      expect(await controller.deleteSet(1), isFalse);
      expect(repository.deleteCalls, 1);

      repository.failReads = false;
      repository.failReadsAfterWrite = false;

      expect(await controller.load(), isTrue);
      expect(controller.completedSessions, 1);
      expect(controller.totalSets, 1);
      expect(controller.sessions.single.logs.single.id, 2);
    });

    test('Renaming preserves the current stored completion status', () async {
      final repository = HistoryEditingRepository([
        log(id: 1, finished: false),
      ]);
      final controller = await loadController(repository);

      repository.records[0] = repository.records[0].copyWith(
        sessionFinished: true,
      );

      expect(
        await controller.renameSession(
          sessionKey: 'completed-session',
          label: 'Completed elsewhere',
        ),
        isTrue,
      );

      expect(repository.records.single.sessionFinished, isTrue);
      expect(controller.completedSessions, 1);
      expect(controller.unfinishedSessions, 0);
    });
  });
}
