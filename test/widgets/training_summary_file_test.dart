import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/models/training_summary.dart';
import 'package:movement_quest/repositories/summary_file_repository.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';
import 'package:movement_quest/services/training_summary_service.dart';
import 'package:movement_quest/widgets/training_summary_panel.dart';
import 'package:provider/provider.dart';

class SummaryFileTestRepository implements SummaryFileRepository {
  TrainingSummary? stored;

  bool failSave = false;
  bool failRead = false;
  bool invalidFile = false;

  int saveCalls = 0;
  int readCalls = 0;

  @override
  Future<void> save(TrainingSummary summary) async {
    saveCalls++;

    if (failSave) {
      throw Exception('Save failed.');
    }

    stored = summary;
    invalidFile = false;
  }

  @override
  Future<TrainingSummary?> read() async {
    readCalls++;

    if (invalidFile) {
      throw const FormatException('Invalid summary.');
    }

    if (failRead) {
      throw Exception('Read failed.');
    }

    return stored;
  }
}

class SummaryFileTestLogs extends Fake implements TrainingLogRepository {
  @override
  Future<List<TrainingLog>> getLogs({int? workoutId}) async => [];
}

class SummaryFileTestService extends TrainingSummaryService {
  int generateCalls = 0;

  @override
  Future<TrainingSummary> generate(List<TrainingLog> logs) async {
    generateCalls++;

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
  TrainingSummary savedSummary() {
    return TrainingSummary(
      generatedAtUtc: DateTime.utc(2026, 10, 24, 9),
      completedSessions: 1,
      unfinishedSessions: 0,
      totalSets: 1,
      totalRepetitions: 30,
    );
  }

  Future<void> openPanel(
    WidgetTester tester,
    SummaryFileTestRepository files,
    SummaryFileTestService service,
  ) async {
    await tester.pumpWidget(
      Provider<TrainingLogRepository>(
        create: (_) => SummaryFileTestLogs(),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                TrainingSummaryPanel(service: service, fileRepository: files),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) {
    return tapControl(
      tester,
      find.widgetWithText(FilledButton, 'Generate summary'),
    );
  }

  Future<void> save(WidgetTester tester) {
    return tapControl(
      tester,
      find.widgetWithText(FilledButton, 'Save summary'),
    );
  }

  Future<void> read(WidgetTester tester) {
    return tapControl(
      tester,
      find.widgetWithText(OutlinedButton, 'Read saved summary'),
    );
  }

  testWidgets('A generated summary can be saved', (tester) async {
    final files = SummaryFileTestRepository();
    final service = SummaryFileTestService();

    await openPanel(tester, files, service);

    expect(find.text('Save summary'), findsNothing);

    await generate(tester);
    await save(tester);

    expect(files.saveCalls, 1);
    expect(files.stored, isNotNull);
    expect(files.stored!.totalSets, 2);
    expect(files.stored!.totalRepetitions, 18);
    expect(find.text('Summary saved on this device.'), findsOneWidget);
  });

  testWidgets('Reading displays the saved snapshot without generating', (
    tester,
  ) async {
    final files = SummaryFileTestRepository();
    files.stored = savedSummary();

    final service = SummaryFileTestService();

    await openPanel(tester, files, service);
    await read(tester);

    expect(files.readCalls, 1);
    expect(service.generateCalls, 0);
    expect(files.saveCalls, 0);
    expect(find.text('Saved file snapshot'), findsOneWidget);
    expect(find.text('Saved summary loaded.'), findsOneWidget);
    expect(find.text('Total sets: 1'), findsOneWidget);
    expect(find.text('Total repetitions: 30'), findsOneWidget);
  });

  testWidgets('A missing file gives instructions without generating', (
    tester,
  ) async {
    final files = SummaryFileTestRepository();
    final service = SummaryFileTestService();

    await openPanel(tester, files, service);
    await read(tester);

    expect(
      find.text('No saved summary found. Generate and save one first.'),
      findsOneWidget,
    );
    expect(find.text('Save summary'), findsNothing);
    expect(service.generateCalls, 0);
    expect(files.saveCalls, 0);
  });

  testWidgets('A failed save preserves the summary and allows retry', (
    tester,
  ) async {
    final files = SummaryFileTestRepository();
    files.failSave = true;

    final service = SummaryFileTestService();

    await openPanel(tester, files, service);
    await generate(tester);
    await save(tester);

    expect(files.stored, isNull);
    expect(find.text('Total repetitions: 18'), findsOneWidget);
    expect(
      find.text('Could not save your summary file. Try again.'),
      findsOneWidget,
    );

    files.failSave = false;

    await save(tester);

    expect(files.saveCalls, 2);
    expect(files.stored!.totalRepetitions, 18);
    expect(find.text('Summary saved on this device.'), findsOneWidget);
    expect(
      find.text('Could not save your summary file. Try again.'),
      findsNothing,
    );
  });

  testWidgets('A failed read allows another attempt', (tester) async {
    final files = SummaryFileTestRepository();
    files.stored = savedSummary();
    files.failRead = true;

    final service = SummaryFileTestService();

    await openPanel(tester, files, service);
    await read(tester);

    expect(
      find.text('Could not read your summary file. Try again.'),
      findsOneWidget,
    );

    files.failRead = false;

    await read(tester);

    expect(files.readCalls, 2);
    expect(find.text('Saved file snapshot'), findsOneWidget);
    expect(find.text('Total repetitions: 30'), findsOneWidget);
    expect(
      find.text('Could not read your summary file. Try again.'),
      findsNothing,
    );
  });

  testWidgets('An invalid file can be replaced with a generated summary', (
    tester,
  ) async {
    final files = SummaryFileTestRepository();
    files.invalidFile = true;

    final service = SummaryFileTestService();

    await openPanel(tester, files, service);
    await read(tester);

    expect(
      find.text(
        'The saved summary is invalid or uses an unsupported version. '
        'Generate a new summary and save it to replace the file.',
      ),
      findsOneWidget,
    );

    await generate(tester);
    await save(tester);
    await read(tester);

    expect(files.invalidFile, isFalse);
    expect(files.saveCalls, 1);
    expect(files.readCalls, 2);
    expect(find.text('Saved file snapshot'), findsOneWidget);
    expect(find.text('Total repetitions: 18'), findsOneWidget);
  });

  testWidgets('Reading a missing file preserves an existing display', (
    tester,
  ) async {
    final files = SummaryFileTestRepository();
    final service = SummaryFileTestService();

    await openPanel(tester, files, service);
    await generate(tester);
    await read(tester);

    expect(find.text('Generated snapshot'), findsOneWidget);
    expect(find.text('Total repetitions: 18'), findsOneWidget);
    expect(
      find.text('No saved summary found. Generate and save one first.'),
      findsOneWidget,
    );
    expect(files.stored, isNull);
  });
}
