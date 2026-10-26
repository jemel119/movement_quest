import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';
import 'package:movement_quest/screens/history_screen.dart';
import 'package:provider/provider.dart';

class HistoryEditingScreenRepository extends Fake
    implements TrainingLogRepository {
  final List<TrainingLog> records;

  int updateCalls = 0;
  int deleteCalls = 0;
  int renameCalls = 0;

  HistoryEditingScreenRepository(this.records);

  @override
  Future<List<TrainingLog>> getLogs({int? workoutId}) async {
    return records
        .where((log) => workoutId == null || log.workoutId == workoutId)
        .toList();
  }

  @override
  Future<TrainingLog?> getLog(int id) async {
    for (final log in records) {
      if (log.id == id) return log;
    }

    return null;
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
    renameCalls++;

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
}

void main() {
  TrainingLog log(int id) {
    return TrainingLog(
      id: id,
      workoutId: 7,
      sessionKey: 'completed-session',
      sessionLabel: 'Morning session',
      exerciseLabel: 'Exercise $id',
      repetitions: 8,
      loggedAt: DateTime.utc(2026, 10, 25, 10),
      sessionFinished: true,
    );
  }

  Finder dialogField(String label) {
    return find.descendant(
      of: find.byType(AlertDialog),
      matching: find.ancestor(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == label,
        ),
        matching: find.byType(TextFormField),
      ),
    );
  }

  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openHistory(
    WidgetTester tester,
    HistoryEditingScreenRepository repository,
  ) async {
    await tester.pumpWidget(
      Provider<TrainingLogRepository>.value(
        value: repository,
        child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
      ),
    );

    await tester.pumpAndSettle();

    await tapControl(tester, find.text('Morning session'));
  }

  testWidgets('Editing a completed set updates its values and totals', (
    tester,
  ) async {
    final original = log(1);
    final repository = HistoryEditingScreenRepository([original]);

    await openHistory(tester, repository);

    await tapControl(tester, find.widgetWithText(TextButton, 'Edit set'));

    await tester.enterText(dialogField('Exercise label'), ' Updated exercise ');
    await tester.enterText(dialogField('Repetitions'), '15');

    await tapControl(tester, find.widgetWithText(FilledButton, 'Save changes'));

    final updated = repository.records.single;

    expect(repository.updateCalls, 1);
    expect(updated.id, original.id);
    expect(updated.sessionKey, original.sessionKey);
    expect(updated.loggedAt, original.loggedAt);
    expect(updated.sessionFinished, isTrue);
    expect(updated.exerciseLabel, 'Updated exercise');
    expect(updated.repetitions, 15);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Total repetitions: 15'), findsOneWidget);
    expect(find.text('Completed sessions: 1'), findsOneWidget);
  });

  testWidgets('Invalid repetitions are rejected in the edit dialog', (
    tester,
  ) async {
    final repository = HistoryEditingScreenRepository([log(1)]);

    await openHistory(tester, repository);

    await tapControl(tester, find.widgetWithText(TextButton, 'Edit set'));

    await tester.enterText(dialogField('Repetitions'), '2.5');

    await tapControl(tester, find.widgetWithText(FilledButton, 'Save changes'));

    expect(find.text('Enter a positive whole number.'), findsOneWidget);
    expect(repository.updateCalls, 0);
    expect(repository.records.single.repetitions, 8);

    await tapControl(tester, find.widgetWithText(TextButton, 'Cancel'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.updateCalls, 0);
  });

  testWidgets('Renaming changes every set without changing completion', (
    tester,
  ) async {
    final repository = HistoryEditingScreenRepository([log(1), log(2)]);

    await openHistory(tester, repository);

    await tapControl(tester, find.widgetWithText(TextButton, 'Rename session'));

    await tester.enterText(dialogField('Session label'), ' Updated session ');

    await tapControl(tester, find.widgetWithText(FilledButton, 'Save changes'));

    expect(repository.renameCalls, 1);
    expect(repository.records, hasLength(2));
    expect(
      repository.records.every(
        (record) =>
            record.sessionLabel == 'Updated session' &&
            record.sessionKey == 'completed-session' &&
            record.sessionFinished,
      ),
      isTrue,
    );
    expect(find.text('Updated session'), findsOneWidget);
    expect(find.text('Completed sessions: 1'), findsOneWidget);
    expect(find.text('Total sets: 2'), findsOneWidget);
  });

  testWidgets('Blank session labels are rejected', (tester) async {
    final repository = HistoryEditingScreenRepository([log(1)]);

    await openHistory(tester, repository);

    await tapControl(tester, find.widgetWithText(TextButton, 'Rename session'));

    await tester.enterText(dialogField('Session label'), '   ');

    await tapControl(tester, find.widgetWithText(FilledButton, 'Save changes'));

    expect(find.text('Enter a session label.'), findsOneWidget);
    expect(repository.renameCalls, 0);
    expect(repository.records.single.sessionLabel, 'Morning session');
  });

  testWidgets('Deletion can be cancelled before removing the final set', (
    tester,
  ) async {
    final repository = HistoryEditingScreenRepository([log(1)]);

    await openHistory(tester, repository);

    await tapControl(tester, find.widgetWithText(TextButton, 'Delete set'));

    expect(find.text('Delete saved set?'), findsOneWidget);
    expect(
      find.textContaining(
        'If this is the final set, its session will disappear',
      ),
      findsOneWidget,
    );

    await tapControl(tester, find.widgetWithText(TextButton, 'Cancel'));

    expect(repository.deleteCalls, 0);
    expect(repository.records, hasLength(1));

    await tapControl(tester, find.widgetWithText(TextButton, 'Delete set'));

    await tapControl(tester, find.widgetWithText(FilledButton, 'Delete'));

    expect(repository.deleteCalls, 1);
    expect(repository.records, isEmpty);
    expect(find.text('Completed sessions: 0'), findsOneWidget);
    expect(find.text('Total sets: 0'), findsOneWidget);
    expect(find.text('No training history yet.'), findsOneWidget);
  });
}
