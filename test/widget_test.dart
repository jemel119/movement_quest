import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/workout_controller.dart';
import 'package:movement_quest/main.dart';
import 'package:movement_quest/models/workout_plan.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';
import 'package:movement_quest/repositories/workout_repository.dart';
import 'package:provider/provider.dart';
import 'package:movement_quest/controllers/preferences_controller.dart';
import 'package:movement_quest/repositories/shared_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movement_quest/models/training_log.dart';

class FakeWorkoutRepository extends Fake implements WorkoutRepository {
  final List<WorkoutPlan> records;

  bool failWrites = false;
  bool failReads = false;
  bool failReadsAfterWrite = false;
  bool failDeletes = false;

  Completer<void>? createGate;

  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  FakeWorkoutRepository(List<WorkoutPlan> initialRecords)
    : records = List.of(initialRecords);

  @override
  Future<List<WorkoutPlan>> getPlans({String? equipmentTag}) async {
    if (failReads) {
      throw Exception('Read failed.');
    }

    return records
        .where(
          (plan) => equipmentTag == null || plan.equipmentTag == equipmentTag,
        )
        .toList();
  }

  @override
  Future<WorkoutPlan> createPlan(WorkoutPlan plan) async {
    createCalls++;

    final gate = createGate;

    if (gate != null) {
      await gate.future;
    }

    if (failWrites) {
      throw Exception('Save failed.');
    }

    final nextId =
        records.fold<int>(0, (largest, record) {
          final id = record.id ?? 0;
          return id > largest ? id : largest;
        }) +
        1;

    final saved = plan.copyWith(id: nextId);
    records.add(saved);

    if (failReadsAfterWrite) {
      failReads = true;
    }

    return saved;
  }

  @override
  Future<WorkoutPlan> updatePlan(WorkoutPlan plan) async {
    updateCalls++;

    if (failWrites) {
      throw Exception('Save failed.');
    }

    final index = records.indexWhere((record) => record.id == plan.id);

    if (index == -1) {
      throw StateError('Workout plan not found.');
    }

    records[index] = plan;

    if (failReadsAfterWrite) {
      failReads = true;
    }

    return plan;
  }

  @override
  Future<void> deletePlan(int id) async {
    deleteCalls++;

    if (failDeletes) {
      throw Exception('Delete failed.');
    }

    final index = records.indexWhere((plan) => plan.id == id);

    if (index == -1) {
      throw StateError('Workout plan not found.');
    }

    records.removeAt(index);
  }
}

class FakeTrainingLogRepository extends Fake implements TrainingLogRepository {
  @override
  Future<int> countFinishedSessions({int? workoutId}) async => 2;

  @override
  Future<List<TrainingLog>> getLogs({int? workoutId}) async => [];
}

void main() {
  Future<WorkoutController> openApp(
    WidgetTester tester,
    FakeWorkoutRepository repository,
  ) async {
    final trainingRepository = FakeTrainingLogRepository();

    final controller = WorkoutController(repository, trainingRepository);

    SharedPreferences.setMockInitialValues({});

    final storage = await SharedPreferences.getInstance();

    final preferencesController = PreferencesController(
      SharedPreferencesRepository(storage),
    );

    addTearDown(controller.dispose);
    addTearDown(preferencesController.dispose);

    await controller.load();
    await preferencesController.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutRepository>.value(value: repository),
          Provider<TrainingLogRepository>.value(value: trainingRepository),
          ChangeNotifierProvider<WorkoutController>.value(value: controller),
          ChangeNotifierProvider<PreferencesController>.value(
            value: preferencesController,
          ),
        ],
        child: const MovementQuestApp(),
      ),
    );

    await tester.pumpAndSettle();

    return controller;
  }

  FakeWorkoutRepository exampleRepository() {
    return FakeWorkoutRepository([
      WorkoutPlan(
        id: 1,
        title: 'No-equipment routine',
        equipmentTag: 'None',
        effortPreference: 2,
      ),
      WorkoutPlan(
        id: 2,
        title: 'Band routine',
        equipmentTag: 'Band',
        effortPreference: 3,
      ),
    ]);
  }

  Future<void> openAddForm(WidgetTester tester) async {
    await tester.tap(find.text('Add plan'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Save plan');

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
  }

  testWidgets('Navigation switches between the main pages', (tester) async {
    await openApp(tester, exampleRepository());

    expect(find.text('No-equipment routine'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Session history'), findsOneWidget);
    expect(find.text('No training history yet.'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Workout preferences'), findsOneWidget);

    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();

    expect(find.text('No-equipment routine'), findsOneWidget);
    expect(find.text('Band routine'), findsOneWidget);
  });

  testWidgets('Equipment filtering updates the visible plans', (tester) async {
    await openApp(tester, exampleRepository());

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Band').last);
    await tester.pumpAndSettle();

    expect(find.text('Band routine'), findsOneWidget);
    expect(find.text('No-equipment routine'), findsNothing);
    expect(find.text('Completed sessions: 2'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dumbbells').last);
    await tester.pumpAndSettle();

    expect(find.text('No plans match this equipment filter.'), findsOneWidget);
    expect(find.text('Completed sessions: 2'), findsOneWidget);
  });

  testWidgets('An empty repository shows the empty catalog', (tester) async {
    await openApp(tester, FakeWorkoutRepository([]));

    expect(find.text('No workout plans yet.'), findsOneWidget);
    expect(find.text('Add plan'), findsOneWidget);
  });

  testWidgets('A blank title is rejected without saving', (tester) async {
    final repository = FakeWorkoutRepository([]);

    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(find.byType(TextFormField).first, '  ');

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text('Enter a workout title.'), findsOneWidget);
    expect(repository.createCalls, 0);
    expect(repository.records, isEmpty);
    expect(find.text('Add workout plan'), findsOneWidget);
  });

  testWidgets('A valid form saves trimmed values and closes', (tester) async {
    final repository = FakeWorkoutRepository([]);

    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      ' Evening routine ',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      ' My chosen exercises ',
    );

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.records, hasLength(1));

    final saved = repository.records.single;

    expect(saved.title, 'Evening routine');
    expect(saved.planNote, 'My chosen exercises');
    expect(saved.equipmentTag, 'None');
    expect(saved.effortPreference, 3);
    expect(find.text('Add workout plan'), findsNothing);
    expect(find.text('Evening routine'), findsOneWidget);
  });

  testWidgets('Editing preserves the plan ID and unchanged values', (
    tester,
  ) async {
    final repository = FakeWorkoutRepository([
      WorkoutPlan(
        id: 7,
        title: 'Original routine',
        equipmentTag: 'Band',
        planNote: 'Original note',
        effortPreference: 4,
      ),
    ]);

    await openApp(tester, repository);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit workout plan'), findsOneWidget);

    final titleField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    final noteField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );

    expect(titleField.controller!.text, 'Original routine');
    expect(noteField.controller!.text, 'Original note');

    await tester.enterText(find.byType(TextFormField).first, 'Updated routine');

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    expect(repository.updateCalls, 1);
    expect(repository.records, hasLength(1));

    final saved = repository.records.single;

    expect(saved.id, 7);
    expect(saved.title, 'Updated routine');
    expect(saved.equipmentTag, 'Band');
    expect(saved.planNote, 'Original note');
    expect(saved.effortPreference, 4);
    expect(find.text('Updated routine'), findsOneWidget);
  });

  testWidgets('Cancel allows keeping or discarding unsaved changes', (
    tester,
  ) async {
    final repository = FakeWorkoutRepository([]);

    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Unsaved routine');

    final cancelButton = find.widgetWithText(TextButton, 'Cancel');

    await tester.ensureVisible(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    final titleField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );

    expect(titleField.controller!.text, 'Unsaved routine');

    await tester.ensureVisible(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(repository.records, isEmpty);
    expect(repository.createCalls, 0);
    expect(find.text('Add workout plan'), findsNothing);
    expect(find.text('Add plan'), findsOneWidget);
  });

  testWidgets('System Back confirms before discarding changes', (tester) async {
    final repository = FakeWorkoutRepository([]);

    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Unsaved routine');

    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(repository.records, isEmpty);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Add workout plan'), findsNothing);
    expect(find.text('Add plan'), findsOneWidget);
    expect(repository.records, isEmpty);
  });

  testWidgets('A failed save preserves input and allows retry', (tester) async {
    final repository = FakeWorkoutRepository([]);
    repository.failWrites = true;

    final controller = await openApp(tester, repository);

    await openAddForm(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Retry routine');

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.records, isEmpty);
    expect(repository.createCalls, 1);
    expect(controller.error, isNotNull);
    expect(find.text('Add workout plan'), findsOneWidget);

    final titleField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );

    expect(titleField.controller!.text, 'Retry routine');

    repository.failWrites = false;

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 2);
    expect(repository.records, hasLength(1));
    expect(repository.records.single.title, 'Retry routine');
    expect(find.text('Add workout plan'), findsNothing);
    expect(find.text('Retry routine'), findsOneWidget);
  });

  testWidgets('A pending save disables submission and blocks Back', (
    tester,
  ) async {
    final repository = FakeWorkoutRepository([]);
    final gate = Completer<void>();

    repository.createGate = gate;

    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Pending routine');

    await tapSave(tester);
    await tester.pump();

    expect(repository.createCalls, 1);

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Saving...'),
    );

    expect(saveButton.onPressed, isNull);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Add workout plan'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.records, hasLength(1));
    expect(find.text('Add workout plan'), findsNothing);
    expect(find.text('Pending routine'), findsOneWidget);
  });

  testWidgets('A refresh failure after saving does not duplicate the plan', (
    tester,
  ) async {
    final repository = FakeWorkoutRepository([]);
    repository.failReadsAfterWrite = true;

    final controller = await openApp(tester, repository);

    await openAddForm(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Saved routine');

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.records, hasLength(1));
    expect(find.text('Add workout plan'), findsNothing);
    expect(controller.error, isNotNull);
    expect(find.text(controller.error!), findsOneWidget);

    repository.failReads = false;

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.records, hasLength(1));
    expect(find.text('Saved routine'), findsOneWidget);
    expect(controller.error, isNull);
  });

  testWidgets('Cancelling deletion keeps the workout plan', (tester) async {
    final repository = exampleRepository();

    await openApp(tester, repository);

    await tester.tap(find.widgetWithText(TextButton, 'Delete').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete workout plan?'), findsOneWidget);
    expect(
      find.text(
        'Delete "No-equipment routine" and all its training logs? '
        'This cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(repository.records, hasLength(2));
    expect(find.text('No-equipment routine'), findsOneWidget);
    expect(find.text('Delete workout plan?'), findsNothing);
  });

  testWidgets('Confirming deletion removes only the selected plan', (
    tester,
  ) async {
    final repository = exampleRepository();

    await openApp(tester, repository);

    await tester.tap(find.widgetWithText(TextButton, 'Delete').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.records, hasLength(1));
    expect(repository.records.single.title, 'Band routine');
    expect(find.text('No-equipment routine'), findsNothing);
    expect(find.text('Band routine'), findsOneWidget);
    expect(find.text('Workout plan deleted.'), findsOneWidget);
  });

  testWidgets('Deleting the final plan shows the empty catalog', (
    tester,
  ) async {
    final repository = FakeWorkoutRepository([
      WorkoutPlan(
        id: 1,
        title: 'Only routine',
        equipmentTag: 'None',
        effortPreference: 2,
      ),
    ]);

    await openApp(tester, repository);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.records, isEmpty);
    expect(find.text('Only routine'), findsNothing);
    expect(find.text('No workout plans yet.'), findsOneWidget);
  });

  testWidgets('Failed deletion keeps the plan and allows another attempt', (
    tester,
  ) async {
    final repository = exampleRepository();
    repository.failDeletes = true;

    final controller = await openApp(tester, repository);

    await tester.tap(find.widgetWithText(TextButton, 'Delete').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.records, hasLength(2));
    expect(find.text('No-equipment routine'), findsOneWidget);
    expect(controller.error, isNotNull);
    expect(find.text(controller.error!), findsOneWidget);
    expect(find.text('Workout plan deleted.'), findsNothing);

    repository.failDeletes = false;

    await tester.tap(find.widgetWithText(TextButton, 'Delete').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 2);
    expect(repository.records, hasLength(1));
    expect(find.text('No-equipment routine'), findsNothing);
    expect(find.text('Band routine'), findsOneWidget);
    expect(controller.error, isNull);
  });
}
