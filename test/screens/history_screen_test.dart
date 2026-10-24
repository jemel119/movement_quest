import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';
import 'package:movement_quest/screens/history_screen.dart';
import 'package:provider/provider.dart';

class HistoryScreenRepository extends Fake implements TrainingLogRepository {
  List<TrainingLog> records = [];

  bool failReads = false;
  int readCalls = 0;

  @override
  Future<List<TrainingLog>> getLogs({int? workoutId}) async {
    readCalls++;

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
    String label = 'Morning session',
    int repetitions = 8,
    bool finished = true,
  }) {
    return TrainingLog(
      id: id,
      workoutId: 7,
      sessionKey: key,
      sessionLabel: label,
      exerciseLabel: 'Exercise $id',
      repetitions: repetitions,
      loggedAt: DateTime.utc(2026, 10, 24, 10),
      sessionFinished: finished,
    );
  }

  Future<void> openHistory(
    WidgetTester tester,
    HistoryScreenRepository repository, {
    bool isActive = true,
  }) async {
    await tester.pumpWidget(
      Provider<TrainingLogRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Scaffold(body: HistoryScreen(isActive: isActive)),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Empty history displays zero totals and an empty message', (
    tester,
  ) async {
    final repository = HistoryScreenRepository();

    await openHistory(tester, repository);

    expect(find.text('Session history'), findsOneWidget);
    expect(find.text('Completed sessions: 0'), findsOneWidget);
    expect(find.text('Unfinished sessions: 0'), findsOneWidget);
    expect(find.text('Total sets: 0'), findsOneWidget);
    expect(find.text('Total repetitions: 0'), findsOneWidget);
    expect(find.text('No training history yet.'), findsOneWidget);
  });

  testWidgets('History counts grouped sessions separately from sets', (
    tester,
  ) async {
    final repository = HistoryScreenRepository();
    repository.records = [
      log(id: 1, repetitions: 8),
      log(id: 2, repetitions: 10),
      log(id: 3, repetitions: 12),
      log(
        id: 4,
        key: 'unfinished-session',
        label: 'Evening session',
        repetitions: 5,
        finished: false,
      ),
    ];

    await openHistory(tester, repository);

    expect(find.text('Completed sessions: 1'), findsOneWidget);
    expect(find.text('Unfinished sessions: 1'), findsOneWidget);
    expect(find.text('Total sets: 4'), findsOneWidget);
    expect(find.text('Total repetitions: 35'), findsOneWidget);
    expect(find.text('Morning session'), findsOneWidget);
    expect(find.text('Evening session'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNWidgets(2));
  });

  testWidgets('Expanding a session displays its saved sets', (tester) async {
    final repository = HistoryScreenRepository();
    repository.records = [
      log(id: 1, repetitions: 8),
      log(id: 2, repetitions: 10),
    ];

    await openHistory(tester, repository);

    await tester.tap(find.text('Morning session'));
    await tester.pumpAndSettle();

    expect(find.text('Exercise 1'), findsOneWidget);
    expect(find.text('Exercise 2'), findsOneWidget);
    expect(find.text('8 repetitions'), findsOneWidget);
    expect(find.text('10 repetitions'), findsOneWidget);
    expect(find.text('Session repetitions: 18'), findsOneWidget);

    final viewButton = find.widgetWithText(TextButton, 'View workout');

    await tester.ensureVisible(viewButton);
    await tester.pumpAndSettle();

    expect(tester.widget<TextButton>(viewButton).onPressed, isNotNull);
  });

  testWidgets('Refresh reflects deleted history', (tester) async {
    final repository = HistoryScreenRepository();
    repository.records = [log(id: 1)];

    await openHistory(tester, repository);

    expect(find.text('Completed sessions: 1'), findsOneWidget);

    repository.records.clear();

    await tester.tap(find.byTooltip('Refresh history'));
    await tester.pumpAndSettle();

    expect(repository.readCalls, 2);
    expect(find.text('Completed sessions: 0'), findsOneWidget);
    expect(find.text('Total sets: 0'), findsOneWidget);
    expect(find.text('No training history yet.'), findsOneWidget);
  });

  testWidgets('A failed initial load provides a working retry', (tester) async {
    final repository = HistoryScreenRepository();
    repository.failReads = true;

    await openHistory(tester, repository);

    expect(
      find.text('Could not load your training history. Try again.'),
      findsOneWidget,
    );
    expect(
      find.text('Your training history could not be loaded.'),
      findsOneWidget,
    );

    repository.failReads = false;
    repository.records = [log(id: 1)];

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Completed sessions: 1'), findsOneWidget);
    expect(find.text('Morning session'), findsOneWidget);
    expect(
      find.text('Could not load your training history. Try again.'),
      findsNothing,
    );
  });

  testWidgets('A failed refresh keeps previously displayed history', (
    tester,
  ) async {
    final repository = HistoryScreenRepository();
    repository.records = [log(id: 1)];

    await openHistory(tester, repository);

    repository.failReads = true;

    await tester.tap(find.byTooltip('Refresh history'));
    await tester.pumpAndSettle();

    expect(find.text('Morning session'), findsOneWidget);
    expect(find.text('Completed sessions: 1'), findsOneWidget);
    expect(
      find.text('Could not load your training history. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('History loads on activation and refreshes on reactivation', (
    tester,
  ) async {
    final repository = HistoryScreenRepository();

    await openHistory(tester, repository, isActive: false);

    expect(repository.readCalls, 0);

    await openHistory(tester, repository);

    expect(repository.readCalls, 1);
    expect(find.text('No training history yet.'), findsOneWidget);

    await openHistory(tester, repository, isActive: false);

    repository.records = [log(id: 1)];

    await openHistory(tester, repository);

    expect(repository.readCalls, 2);
    expect(find.text('Morning session'), findsOneWidget);
    expect(find.text('Completed sessions: 1'), findsOneWidget);
  });
}
