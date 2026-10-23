import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/session_controller.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';

class SessionTestRepository extends Fake implements TrainingLogRepository {
  final List<TrainingLog> records;

  bool failReads = false;
  bool failCreates = false;
  bool failReadsAfterCreate = false;

  int createCalls = 0;
  int finishCalls = 0;
  int resetCalls = 0;
  int _nextId = 1;

  SessionTestRepository([List<TrainingLog> initial = const []])
    : records = List.of(initial) {
    for (final log in records) {
      final id = log.id ?? 0;

      if (id >= _nextId) {
        _nextId = id + 1;
      }
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
  Future<TrainingLog> createLog(TrainingLog log) async {
    createCalls++;

    if (failCreates) {
      throw Exception('Create failed.');
    }

    final saved = log.copyWith(id: _nextId++);
    records.add(saved);

    if (failReadsAfterCreate) {
      failReads = true;
    }

    return saved;
  }

  @override
  Future<void> updateSession({
    required int workoutId,
    required String sessionKey,
    required String sessionLabel,
    required bool sessionFinished,
  }) async {
    finishCalls++;

    final matches = records.where(
      (log) => log.workoutId == workoutId && log.sessionKey == sessionKey,
    );

    if (matches.isEmpty) {
      throw StateError('Session not found.');
    }

    for (var index = 0; index < records.length; index++) {
      final log = records[index];

      if (log.workoutId == workoutId && log.sessionKey == sessionKey) {
        records[index] = log.copyWith(
          sessionLabel: sessionLabel,
          sessionFinished: sessionFinished,
        );
      }
    }
  }

  @override
  Future<int> deleteUnfinishedSession({
    required int workoutId,
    required String sessionKey,
  }) async {
    resetCalls++;

    final before = records.length;

    records.removeWhere(
      (log) =>
          log.workoutId == workoutId &&
          log.sessionKey == sessionKey &&
          !log.sessionFinished,
    );

    return before - records.length;
  }
}

void main() {
  TrainingLog savedLog({
    int id = 1,
    int workoutId = 7,
    String sessionKey = 'saved-session',
    String sessionLabel = 'Saved session',
    bool finished = false,
  }) {
    return TrainingLog(
      id: id,
      workoutId: workoutId,
      sessionKey: sessionKey,
      sessionLabel: sessionLabel,
      exerciseLabel: 'My exercise',
      repetitions: 8,
      loggedAt: DateTime.utc(2026, 10, 23, 10),
      sessionFinished: finished,
    );
  }

  SessionController createController(SessionTestRepository repository) {
    final controller = SessionController(repository, workoutId: 7);

    addTearDown(controller.dispose);
    return controller;
  }

  group('SessionController', () {
    test('Rejects a nonpositive workout ID', () {
      expect(
        () => SessionController(SessionTestRepository(), workoutId: 0),
        throwsArgumentError,
      );
    });

    test('Starting is blocked before loading', () {
      final controller = createController(SessionTestRepository());

      expect(controller.startSession('Morning session'), isFalse);
      expect(controller.hasActiveSession, isFalse);
    });

    test('An empty label is rejected and a valid label is trimmed', () async {
      final controller = createController(SessionTestRepository());

      await controller.load();

      expect(controller.startSession('   '), isFalse);
      expect(controller.error, 'Enter a session label.');
      expect(controller.hasActiveSession, isFalse);

      expect(controller.startSession(' Morning session '), isTrue);
      expect(controller.sessionLabel, 'Morning session');
      expect(controller.sessionKey, isNotEmpty);
      expect(controller.error, isNull);
    });

    test(
      'Starting another session cannot replace the active session',
      () async {
        final controller = createController(SessionTestRepository());

        await controller.load();
        controller.startSession('First session');

        final originalKey = controller.sessionKey;

        expect(controller.startSession('Second session'), isFalse);
        expect(controller.sessionKey, originalKey);
        expect(controller.sessionLabel, 'First session');
      },
    );

    test('Sets share a stable session key and label', () async {
      final repository = SessionTestRepository();
      final controller = createController(repository);

      await controller.load();
      controller.startSession('Morning session');

      final originalKey = controller.sessionKey;

      expect(
        await controller.addSet(
          exerciseLabel: ' First exercise ',
          repetitions: 8,
        ),
        isTrue,
      );
      expect(
        await controller.addSet(
          exerciseLabel: 'Second exercise',
          repetitions: 12,
        ),
        isTrue,
      );

      expect(repository.records, hasLength(2));
      expect(controller.sessionLogs, hasLength(2));
      expect(
        repository.records.every(
          (log) =>
              log.workoutId == 7 &&
              log.sessionKey == originalKey &&
              log.sessionLabel == 'Morning session' &&
              !log.sessionFinished,
        ),
        isTrue,
      );
      expect(repository.records.first.exerciseLabel, 'First exercise');
      expect(repository.records.first.repetitions, 8);
      expect(repository.records.last.repetitions, 12);
      expect(controller.sessionKey, originalKey);
    });

    test('Invalid sets do not reach the repository', () async {
      final repository = SessionTestRepository();
      final controller = createController(repository);

      await controller.load();
      controller.startSession('Morning session');

      expect(
        await controller.addSet(exerciseLabel: ' ', repetitions: 8),
        isFalse,
      );
      expect(
        await controller.addSet(exerciseLabel: 'My exercise', repetitions: 0),
        isFalse,
      );
      expect(
        await controller.addSet(exerciseLabel: 'My exercise', repetitions: -1),
        isFalse,
      );

      expect(repository.createCalls, 0);
      expect(repository.records, isEmpty);
      expect(controller.error, isNotNull);
    });

    test('An empty session cannot be finished', () async {
      final repository = SessionTestRepository();
      final controller = createController(repository);

      await controller.load();
      controller.startSession('Empty session');

      expect(await controller.finishSession(), isFalse);
      expect(repository.finishCalls, 0);
      expect(controller.hasActiveSession, isTrue);
      expect(
        controller.error,
        'Log at least one set before finishing the session.',
      );
    });

    test('Finishing updates all sets without inserting duplicates', () async {
      final repository = SessionTestRepository();
      final controller = createController(repository);

      await controller.load();
      controller.startSession('Morning session');

      await controller.addSet(exerciseLabel: 'First exercise', repetitions: 8);
      await controller.addSet(
        exerciseLabel: 'Second exercise',
        repetitions: 10,
      );

      final originalIds = repository.records.map((log) => log.id).toList();
      final originalKey = controller.sessionKey;

      expect(await controller.finishSession(), isTrue);

      expect(repository.finishCalls, 1);
      expect(repository.createCalls, 2);
      expect(repository.records, hasLength(2));
      expect(repository.records.map((log) => log.id).toList(), originalIds);
      expect(
        repository.records.every(
          (log) => log.sessionFinished && log.sessionKey == originalKey,
        ),
        isTrue,
      );
      expect(controller.hasActiveSession, isFalse);
      expect(controller.sessionLogs, isEmpty);

      expect(await controller.finishSession(), isFalse);
      expect(repository.finishCalls, 1);
      expect(repository.records, hasLength(2));
    });

    test(
      'Reset removes unfinished sets and preserves finished sessions',
      () async {
        final repository = SessionTestRepository([
          savedLog(id: 1, sessionKey: 'finished-session', finished: true),
        ]);
        final controller = createController(repository);

        await controller.load();
        controller.startSession('Session to reset');

        await controller.addSet(exerciseLabel: 'My exercise', repetitions: 8);

        expect(repository.records, hasLength(2));

        expect(await controller.resetSession(), isTrue);

        expect(repository.resetCalls, 1);
        expect(repository.records, hasLength(1));
        expect(repository.records.single.sessionKey, 'finished-session');
        expect(repository.records.single.sessionFinished, isTrue);
        expect(controller.hasActiveSession, isFalse);
        expect(controller.sessionLabel, isNull);
      },
    );

    test('Loading restores an unfinished session for this workout', () async {
      final repository = SessionTestRepository([
        savedLog(),
        savedLog(id: 2, workoutId: 8, sessionKey: 'other-workout-session'),
      ]);
      final controller = createController(repository);

      expect(await controller.load(), isTrue);

      expect(controller.hasActiveSession, isTrue);
      expect(controller.sessionKey, 'saved-session');
      expect(controller.sessionLabel, 'Saved session');
      expect(controller.sessionLogs, hasLength(1));
      expect(controller.logs, hasLength(1));
      expect(controller.startSession('Another session'), isFalse);
    });

    test(
      'Multiple unfinished sessions are rejected rather than guessed',
      () async {
        final repository = SessionTestRepository([
          savedLog(),
          savedLog(
            id: 2,
            sessionKey: 'second-session',
            sessionLabel: 'Second session',
          ),
        ]);
        final controller = createController(repository);

        expect(await controller.load(), isFalse);
        expect(controller.hasLoaded, isFalse);
        expect(controller.error, isNotNull);
        expect(controller.startSession('Another session'), isFalse);
      },
    );

    test('A failed write blocks changes until a successful reload', () async {
      final repository = SessionTestRepository();
      final controller = createController(repository);

      await controller.load();
      controller.startSession('Morning session');

      repository.failCreates = true;

      expect(
        await controller.addSet(exerciseLabel: 'My exercise', repetitions: 8),
        isFalse,
      );

      expect(controller.hasLoaded, isFalse);
      expect(controller.error, isNotNull);
      expect(repository.createCalls, 1);

      expect(
        await controller.addSet(exerciseLabel: 'My exercise', repetitions: 8),
        isFalse,
      );
      expect(repository.createCalls, 1);

      repository.failCreates = false;

      expect(await controller.load(), isTrue);
      expect(controller.error, isNull);

      expect(
        await controller.addSet(exerciseLabel: 'My exercise', repetitions: 8),
        isTrue,
      );
      expect(repository.records, hasLength(1));
    });

    test('Reload reveals a saved set after its refresh failed', () async {
      final repository = SessionTestRepository();
      final controller = createController(repository);

      await controller.load();
      controller.startSession('Morning session');

      final originalKey = controller.sessionKey;
      repository.failReadsAfterCreate = true;

      expect(
        await controller.addSet(exerciseLabel: 'My exercise', repetitions: 8),
        isFalse,
      );

      expect(repository.records, hasLength(1));
      expect(repository.createCalls, 1);
      expect(controller.hasLoaded, isFalse);

      expect(
        await controller.addSet(exerciseLabel: 'My exercise', repetitions: 8),
        isFalse,
      );
      expect(repository.createCalls, 1);

      repository.failReads = false;
      repository.failReadsAfterCreate = false;

      expect(await controller.load(), isTrue);
      expect(controller.sessionKey, originalKey);
      expect(controller.sessionLogs, hasLength(1));
      expect(repository.records, hasLength(1));
      expect(repository.createCalls, 1);
    });

    test('A failed initial load can be retried', () async {
      final repository = SessionTestRepository();
      repository.failReads = true;

      final controller = createController(repository);

      expect(await controller.load(), isFalse);
      expect(controller.hasLoaded, isFalse);
      expect(controller.isBusy, isFalse);

      repository.failReads = false;

      expect(await controller.load(), isTrue);
      expect(controller.hasLoaded, isTrue);
      expect(controller.error, isNull);
      expect(controller.isBusy, isFalse);
    });
  });
}
