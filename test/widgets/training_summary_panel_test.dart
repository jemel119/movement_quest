import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/models/training_summary.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';
import 'package:movement_quest/services/training_summary_service.dart';
import 'package:movement_quest/widgets/training_summary_panel.dart';
import 'package:provider/provider.dart';

class SummaryPanelRepository extends Fake implements TrainingLogRepository {
  final List<TrainingLog> records;

  bool failReads = false;
  int readCalls = 0;

  SummaryPanelRepository(this.records);

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

class SummaryPanelService extends TrainingSummaryService {
  bool failGeneration = false;
  int generateCalls = 0;

  List<TrainingLog>? receivedLogs;
  Completer<void>? gate;

  @override
  Future<TrainingSummary> generate(List<TrainingLog> logs) async {
    generateCalls++;
    receivedLogs = List.of(logs);

    final pending = gate;

    if (pending != null) {
      await pending.future;
    }

    if (failGeneration) {
      throw Exception('Summary failed.');
    }

    return TrainingSummary(
      generatedAtUtc: DateTime.utc(2026, 10, 25, 12),
      completedSessions: 1,
      unfinishedSessions: 0,
      totalSets: 2,
      totalRepetitions: 18,
    );
  }
}

void main() {
  List<TrainingLog> exampleLogs() {
    return [
      TrainingLog(
        id: 1,
        workoutId: 7,
        sessionKey: 'saved-session',
        sessionLabel: 'Morning session',
        exerciseLabel: 'First exercise',
        repetitions: 8,
        loggedAt: DateTime.utc(2026, 10, 25, 10),
        sessionFinished: true,
      ),
      TrainingLog(
        id: 2,
        workoutId: 7,
        sessionKey: 'saved-session',
        sessionLabel: 'Morning session',
        exerciseLabel: 'Second exercise',
        repetitions: 10,
        loggedAt: DateTime.utc(2026, 10, 25, 10, 5),
        sessionFinished: true,
      ),
    ];
  }

  Future<void> openPanel(
    WidgetTester tester,
    SummaryPanelRepository repository,
    SummaryPanelService service,
  ) async {
    await tester.pumpWidget(
      Provider<TrainingLogRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: [TrainingSummaryPanel(service: service)]),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Generate summary');

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('The summary is generated only when requested', (tester) async {
    final repository = SummaryPanelRepository(exampleLogs());
    final service = SummaryPanelService();

    await openPanel(tester, repository, service);

    expect(repository.readCalls, 0);
    expect(service.generateCalls, 0);
    expect(find.text('Completed sessions: 1'), findsNothing);
    expect(find.text('Generate summary'), findsOneWidget);
  });

  testWidgets('Generation passes saved logs and displays the result', (
    tester,
  ) async {
    final repository = SummaryPanelRepository(exampleLogs());
    final service = SummaryPanelService();

    await openPanel(tester, repository, service);
    await generate(tester);

    expect(repository.readCalls, 1);
    expect(service.generateCalls, 1);
    expect(service.receivedLogs!.map((log) => log.id).toList(), [1, 2]);
    expect(find.text('Completed sessions: 1'), findsOneWidget);
    expect(find.text('Unfinished sessions: 0'), findsOneWidget);
    expect(find.text('Total sets: 2'), findsOneWidget);
    expect(find.text('Total repetitions: 18'), findsOneWidget);
    expect(find.textContaining('Generated:'), findsOneWidget);
    expect(repository.records, hasLength(2));
  });

  testWidgets('A storage failure is shown and can be retried', (tester) async {
    final repository = SummaryPanelRepository(exampleLogs());
    repository.failReads = true;

    final service = SummaryPanelService();

    await openPanel(tester, repository, service);
    await generate(tester);

    expect(service.generateCalls, 0);
    expect(
      find.text('Could not generate your training summary. Try again.'),
      findsOneWidget,
    );

    repository.failReads = false;

    await generate(tester);

    expect(service.generateCalls, 1);
    expect(find.text('Total repetitions: 18'), findsOneWidget);
    expect(
      find.text('Could not generate your training summary. Try again.'),
      findsNothing,
    );
  });

  testWidgets('A summary calculation failure can be retried', (tester) async {
    final repository = SummaryPanelRepository(exampleLogs());
    final service = SummaryPanelService();
    service.failGeneration = true;

    await openPanel(tester, repository, service);
    await generate(tester);

    expect(
      find.text('Could not generate your training summary. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Completed sessions: 1'), findsNothing);

    service.failGeneration = false;

    await generate(tester);

    expect(service.generateCalls, 2);
    expect(find.text('Completed sessions: 1'), findsOneWidget);
  });

  testWidgets('A pending calculation disables another request', (tester) async {
    final repository = SummaryPanelRepository(exampleLogs());
    final service = SummaryPanelService();
    final gate = Completer<void>();

    service.gate = gate;

    await openPanel(tester, repository, service);

    await tester.tap(find.widgetWithText(FilledButton, 'Generate summary'));
    await tester.pump();

    expect(service.generateCalls, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generating summary...'),
    );

    expect(button.onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();

    expect(service.generateCalls, 1);
    expect(find.text('Total repetitions: 18'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Removing the panel during generation is safe', (tester) async {
    final repository = SummaryPanelRepository(exampleLogs());
    final service = SummaryPanelService();
    final gate = Completer<void>();

    service.gate = gate;

    await openPanel(tester, repository, service);

    await tester.tap(find.widgetWithText(FilledButton, 'Generate summary'));
    await tester.pump();

    expect(service.generateCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());

    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
