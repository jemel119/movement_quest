import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/session_controller.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';
import 'package:movement_quest/widgets/workout_session_panel.dart';

class PanelTrainingLogRepository extends Fake implements TrainingLogRepository {
  final List<TrainingLog> records;

  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int finishCalls = 0;
  int resetCalls = 0;

  int _nextId = 1;

  PanelTrainingLogRepository([List<TrainingLog> initial = const []])
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
    return records
        .where((log) => workoutId == null || log.workoutId == workoutId)
        .toList();
  }

  @override
  Future<TrainingLog> createLog(TrainingLog log) async {
    createCalls++;

    final saved = log.copyWith(id: _nextId++);
    records.add(saved);

    return saved;
  }

  @override
  Future<TrainingLog> updateLog(TrainingLog log) async {
    updateCalls++;

    final index = records.indexWhere((record) => record.id == log.id);

    if (index == -1) {
      throw StateError('Set not found.');
    }

    records[index] = log;
    return log;
  }

  @override
  Future<void> deleteLog(int id) async {
    deleteCalls++;

    final index = records.indexWhere((log) => log.id == id);

    if (index == -1) {
      throw StateError('Set not found.');
    }

    records.removeAt(index);
  }

  @override
  Future<void> updateSession({
    required int workoutId,
    required String sessionKey,
    required String sessionLabel,
    required bool sessionFinished,
  }) async {
    finishCalls++;

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
  TrainingLog savedSet({
    int id = 1,
    String sessionKey = 'active-session',
    bool finished = false,
  }) {
    return TrainingLog(
      id: id,
      workoutId: 7,
      sessionKey: sessionKey,
      sessionLabel: finished ? 'Finished session' : 'Morning session',
      exerciseLabel: 'Original exercise',
      repetitions: 8,
      loggedAt: DateTime.utc(2026, 10, 23, 10),
      sessionFinished: finished,
    );
  }

  Finder field(String label) {
    return find
        .ancestor(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.labelText == label,
          ),
          matching: find.byType(TextFormField),
        )
        .last;
  }

  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<SessionController> openPanel(
    WidgetTester tester,
    PanelTrainingLogRepository repository,
  ) async {
    final controller = SessionController(repository, workoutId: 7);

    addTearDown(controller.dispose);

    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [WorkoutSessionPanel(controller: controller)],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    return controller;
  }

  testWidgets('Starting requires a nonblank session label', (tester) async {
    final repository = PanelTrainingLogRepository();
    final controller = await openPanel(tester, repository);

    await tapControl(
      tester,
      find.widgetWithText(FilledButton, 'Start session'),
    );

    expect(find.text('Enter a session label.'), findsOneWidget);
    expect(controller.hasActiveSession, isFalse);

    await tester.enterText(field('Session label'), ' Morning session ');

    await tapControl(
      tester,
      find.widgetWithText(FilledButton, 'Start session'),
    );

    expect(controller.hasActiveSession, isTrue);
    expect(controller.sessionLabel, 'Morning session');
    expect(find.text('Morning session'), findsOneWidget);
    expect(find.text('Sets logged: 0'), findsOneWidget);
    expect(repository.records, isEmpty);
  });

  testWidgets('Invalid repetitions are rejected before saving', (tester) async {
    final repository = PanelTrainingLogRepository([savedSet()]);

    await openPanel(tester, repository);

    await tester.enterText(field('Exercise label'), 'My exercise');

    for (final value in ['2.5', '0', '-1']) {
      await tester.enterText(field('Repetitions'), value);

      await tapControl(tester, find.widgetWithText(FilledButton, 'Add set'));

      expect(find.text('Enter a positive whole number.'), findsOneWidget);
    }

    expect(repository.createCalls, 0);
    expect(repository.records, hasLength(1));
  });

  testWidgets('Adding a valid set uses the active session identity', (
    tester,
  ) async {
    final repository = PanelTrainingLogRepository([savedSet()]);
    final controller = await openPanel(tester, repository);

    await tester.enterText(field('Exercise label'), ' New exercise ');
    await tester.enterText(field('Repetitions'), '12');

    await tapControl(tester, find.widgetWithText(FilledButton, 'Add set'));

    expect(repository.createCalls, 1);
    expect(repository.records, hasLength(2));

    final saved = repository.records.last;

    expect(saved.exerciseLabel, 'New exercise');
    expect(saved.repetitions, 12);
    expect(saved.sessionKey, 'active-session');
    expect(saved.sessionLabel, 'Morning session');
    expect(controller.sessionLogs, hasLength(2));

    expect(
      tester.widget<TextFormField>(field('Exercise label')).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(field('Repetitions')).controller!.text,
      isEmpty,
    );
  });

  testWidgets('Editing a set preserves its identity and timestamp', (
    tester,
  ) async {
    final original = savedSet();
    final repository = PanelTrainingLogRepository([original]);

    await openPanel(tester, repository);

    await tapControl(tester, find.widgetWithText(TextButton, 'Edit set'));

    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(field('Exercise label'), 'Updated exercise');
    await tester.enterText(field('Repetitions'), '15');

    await tapControl(tester, find.widgetWithText(FilledButton, 'Save changes'));

    expect(repository.updateCalls, 1);
    expect(repository.records, hasLength(1));

    final updated = repository.records.single;

    expect(updated.id, original.id);
    expect(updated.workoutId, original.workoutId);
    expect(updated.sessionKey, original.sessionKey);
    expect(updated.sessionLabel, original.sessionLabel);
    expect(updated.loggedAt, original.loggedAt);
    expect(updated.sessionFinished, isFalse);
    expect(updated.exerciseLabel, 'Updated exercise');
    expect(updated.repetitions, 15);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Cancelling deletion preserves the set', (tester) async {
    final repository = PanelTrainingLogRepository([savedSet()]);

    await openPanel(tester, repository);

    await tapControl(tester, find.widgetWithText(TextButton, 'Delete set'));

    expect(find.text('Delete set?'), findsOneWidget);

    await tapControl(tester, find.widgetWithText(TextButton, 'Cancel'));

    expect(repository.deleteCalls, 0);
    expect(repository.records, hasLength(1));
    expect(find.text('Delete set?'), findsNothing);
  });

  testWidgets('Deleting the final set leaves the session open', (tester) async {
    final repository = PanelTrainingLogRepository([savedSet()]);
    final controller = await openPanel(tester, repository);

    await tapControl(tester, find.widgetWithText(TextButton, 'Delete set'));

    await tapControl(tester, find.widgetWithText(FilledButton, 'Delete'));

    expect(repository.deleteCalls, 1);
    expect(repository.records, isEmpty);
    expect(controller.hasActiveSession, isTrue);
    expect(controller.sessionKey, 'active-session');
    expect(find.text('Sets logged: 0'), findsOneWidget);

    final finishButton = find.widgetWithText(FilledButton, 'Finish session');

    await tester.ensureVisible(finishButton);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(finishButton).onPressed, isNull);
  });

  testWidgets('Finishing updates saved sets without creating more rows', (
    tester,
  ) async {
    final original = savedSet();
    final repository = PanelTrainingLogRepository([original]);
    final controller = await openPanel(tester, repository);

    await tapControl(
      tester,
      find.widgetWithText(FilledButton, 'Finish session'),
    );

    expect(repository.finishCalls, 1);
    expect(repository.createCalls, 0);
    expect(repository.records, hasLength(1));
    expect(repository.records.single.id, original.id);
    expect(repository.records.single.sessionFinished, isTrue);
    expect(controller.hasActiveSession, isFalse);
    expect(find.text('Session finished.'), findsOneWidget);

    final startButton = find.widgetWithText(FilledButton, 'Start session');

    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();

    expect(startButton, findsOneWidget);
  });

  testWidgets('Reset requires confirmation and preserves finished logs', (
    tester,
  ) async {
    final repository = PanelTrainingLogRepository([
      savedSet(),
      savedSet(id: 2, sessionKey: 'finished-session', finished: true),
    ]);
    final controller = await openPanel(tester, repository);

    await tapControl(tester, find.widgetWithText(TextButton, 'Reset session'));

    expect(find.text('Reset session?'), findsOneWidget);

    await tapControl(tester, find.widgetWithText(TextButton, 'Cancel'));

    expect(repository.resetCalls, 0);
    expect(repository.records, hasLength(2));
    expect(controller.hasActiveSession, isTrue);

    await tapControl(tester, find.widgetWithText(TextButton, 'Reset session'));

    await tapControl(tester, find.widgetWithText(FilledButton, 'Reset'));

    expect(repository.resetCalls, 1);
    expect(repository.records, hasLength(1));
    expect(repository.records.single.sessionKey, 'finished-session');
    expect(repository.records.single.sessionFinished, isTrue);
    expect(controller.hasActiveSession, isFalse);
  });
}
