import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/history_controller.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';

class HistoryTestRepository extends Fake implements TrainingLogRepository {
  List<TrainingLog> records = [];

  bool failReads = false;
  int readCalls = 0;

  Completer<void>? readGate;

  @override
  Future<List<TrainingLog>> getLogs({int? workoutId}) async {
    readCalls++;

    final gate = readGate;

    if (gate != null) {
      await gate.future;
    }

    if (failReads) {
      throw Exception('Read failed.');
    }

    return records
        .where((log) => workoutId == null || log.workoutId == workoutId)
        .toList();
  }
}

void main() {
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
      loggedAt: DateTime.utc(2026, 10, 24, 10),
      sessionFinished: finished,
    );
  }

  HistoryController createController(HistoryTestRepository repository) {
    final controller = HistoryController(repository);

    addTearDown(controller.dispose);

    return controller;
  }

  group('HistoryController', () {
    test('Starts unloaded with empty totals', () {
      final controller = createController(HistoryTestRepository());

      expect(controller.hasLoaded, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.sessions, isEmpty);
      expect(controller.completedSessions, 0);
      expect(controller.unfinishedSessions, 0);
      expect(controller.totalSets, 0);
      expect(controller.totalRepetitions, 0);
    });

    test('Counts sessions separately from sets and repetitions', () async {
      final repository = HistoryTestRepository();
      repository.records = [
        log(id: 1, repetitions: 8),
        log(id: 2, repetitions: 10),
        log(id: 3, repetitions: 12),
        log(id: 4, key: 'unfinished-session', repetitions: 5, finished: false),
      ];

      final controller = createController(repository);

      expect(await controller.load(), isTrue);
      expect(controller.hasLoaded, isTrue);
      expect(controller.sessions, hasLength(2));
      expect(controller.completedSessions, 1);
      expect(controller.unfinishedSessions, 1);
      expect(controller.totalSets, 4);
      expect(controller.totalRepetitions, 35);
    });

    test('Reload reflects deleted sets and sessions', () async {
      final repository = HistoryTestRepository();
      repository.records = [log(id: 1), log(id: 2)];

      final controller = createController(repository);

      await controller.load();

      expect(controller.completedSessions, 1);
      expect(controller.totalSets, 2);

      repository.records.removeLast();

      await controller.load();

      expect(controller.completedSessions, 1);
      expect(controller.totalSets, 1);

      repository.records.clear();

      await controller.load();

      expect(controller.completedSessions, 0);
      expect(controller.totalSets, 0);
      expect(controller.sessions, isEmpty);
    });

    test('A failed initial load can be retried', () async {
      final repository = HistoryTestRepository();
      repository.failReads = true;

      final controller = createController(repository);

      expect(await controller.load(), isFalse);
      expect(controller.hasLoaded, isFalse);
      expect(controller.isLoading, isFalse);
      expect(
        controller.error,
        'Could not load your training history. Try again.',
      );

      repository.failReads = false;

      expect(await controller.load(), isTrue);
      expect(controller.hasLoaded, isTrue);
      expect(controller.error, isNull);
    });

    test('A failed refresh preserves previously loaded history', () async {
      final repository = HistoryTestRepository();
      repository.records = [log(id: 1)];

      final controller = createController(repository);

      await controller.load();

      repository.failReads = true;

      expect(await controller.load(), isFalse);
      expect(controller.hasLoaded, isTrue);
      expect(controller.completedSessions, 1);
      expect(controller.totalSets, 1);
      expect(controller.error, isNotNull);
    });

    test(
      'Overlapping loads are blocked and loading changes are notified',
      () async {
        final repository = HistoryTestRepository();
        final gate = Completer<void>();

        repository.readGate = gate;

        final controller = createController(repository);
        final loadingStates = <bool>[];

        controller.addListener(() {
          loadingStates.add(controller.isLoading);
        });

        final loading = controller.load();

        expect(controller.isLoading, isTrue);
        expect(await controller.load(), isFalse);
        expect(repository.readCalls, 1);

        gate.complete();

        expect(await loading, isTrue);
        expect(loadingStates, [true, false]);
      },
    );

    test('Inconsistent session data produces an error', () async {
      final repository = HistoryTestRepository();
      repository.records = [log(id: 1), log(id: 2, finished: false)];

      final controller = createController(repository);

      expect(await controller.load(), isFalse);
      expect(controller.hasLoaded, isFalse);
      expect(controller.sessions, isEmpty);
      expect(controller.error, isNotNull);
    });

    test('Disposal during loading prevents later notifications', () async {
      final repository = HistoryTestRepository();
      final gate = Completer<void>();

      repository.readGate = gate;

      final controller = HistoryController(repository);
      var notifications = 0;

      controller.addListener(() {
        notifications++;
      });

      final loading = controller.load();

      expect(notifications, 1);

      controller.dispose();
      gate.complete();

      expect(await loading, isFalse);
      expect(notifications, 1);
      expect(controller.hasLoaded, isFalse);
      expect(await controller.load(), isFalse);
      expect(repository.readCalls, 1);
    });
  });
}
