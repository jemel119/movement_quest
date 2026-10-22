import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/workout_controller.dart';
import 'package:movement_quest/main.dart';
import 'package:movement_quest/models/workout_plan.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';
import 'package:movement_quest/repositories/workout_repository.dart';
import 'package:provider/provider.dart';

class FakeWorkoutRepository extends Fake implements WorkoutRepository {
  final List<WorkoutPlan> records;

  bool failWrites = false;
  bool failReads = false;
  bool failReadsAfterWrite = false;
  Completer<void>? createGate;

  int createCalls = 0;
  int updateCalls = 0;

  FakeWorkoutRepository(List<WorkoutPlan> initialRecords)
    : records = List.of(initialRecords);

  @override
  Future<List<WorkoutPlan>> getPlans({String? equipmentTag}) async {
    if (failReads) {
      throw Exception('Simulated read failure');
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
      throw Exception('Simulated write failure');
    }

    final nextId =
        records.fold<int>(
          0,
          (highest, record) => record.id! > highest ? record.id! : highest,
        ) +
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
      throw Exception('Simulated write failure');
    }

    final index = records.indexWhere((record) => record.id == plan.id);

    if (index == -1) {
      throw StateError('This workout plan no longer exists.');
    }

    records[index] = plan;

    if (failReadsAfterWrite) {
      failReads = true;
    }

    return plan;
  }
}

class FakeTrainingLogRepository extends Fake implements TrainingLogRepository {
  @override
  Future<int> countFinishedSessions({int? workoutId}) async => 2;
}

void main() {
  Future<WorkoutController> openApp(
    WidgetTester tester,
    FakeWorkoutRepository repository,
  ) async {
    final controller = WorkoutController(
      repository,
      FakeTrainingLogRepository(),
    );

    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<WorkoutController>.value(
        value: controller,
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
    final save = find.widgetWithText(FilledButton, 'Save plan');

    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
  }

  testWidgets('Navigation opens each main section', (tester) async {
    await openApp(tester, exampleRepository());

    expect(find.text('Movement Quest'), findsOneWidget);
    expect(find.text('Completed sessions: 2'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'History'));
    await tester.pumpAndSettle();

    expect(find.text('Training History'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Your preferences will appear here.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Workouts'));
    await tester.pumpAndSettle();

    expect(find.text('No-equipment routine'), findsOneWidget);
  });

  testWidgets('Equipment dropdown filters the visible plans', (tester) async {
    await openApp(tester, exampleRepository());

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Band').last);
    await tester.pumpAndSettle();

    expect(find.text('Band routine'), findsOneWidget);
    expect(find.text('No-equipment routine'), findsNothing);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dumbbells').last);
    await tester.pumpAndSettle();

    expect(find.text('No plans match this equipment filter.'), findsOneWidget);
    expect(find.text('Completed sessions: 2'), findsOneWidget);
  });

  testWidgets('Empty catalog displays an explicit message', (tester) async {
    await openApp(tester, FakeWorkoutRepository([]));

    expect(find.text('No workout plans yet.'), findsOneWidget);
  });

  testWidgets('Blank title prevents saving', (tester) async {
    final repository = FakeWorkoutRepository([]);
    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text('Enter a workout title.'), findsOneWidget);
    expect(repository.createCalls, 0);
    expect(repository.records, isEmpty);
  });

  testWidgets('Valid form creates one plan and refreshes the catalog', (
    tester,
  ) async {
    final repository = FakeWorkoutRepository([]);
    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      '  Evening routine  ',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '  My chosen exercises  ',
    );

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.records.length, 1);
    expect(repository.records.single.title, 'Evening routine');
    expect(repository.records.single.planNote, 'My chosen exercises');
    expect(repository.records.single.equipmentTag, 'None');
    expect(repository.records.single.effortPreference, 3);
    expect(find.text('Add workout plan'), findsNothing);
    expect(find.text('Evening routine'), findsOneWidget);
  });

  testWidgets('Edit loads saved fields and updates the existing plan', (
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

    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();

    expect(fields[0].controller!.text, 'Original routine');
    expect(fields[1].controller!.text, 'Original note');
    expect(find.text('Effort preference: 4 of 5'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Corrected routine',
    );

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.createCalls, 0);
    expect(repository.records.single.id, 7);
    expect(repository.records.single.title, 'Corrected routine');
    expect(repository.records.single.equipmentTag, 'Band');
    expect(repository.records.single.planNote, 'Original note');
    expect(repository.records.single.effortPreference, 4);
    expect(find.text('Corrected routine'), findsOneWidget);
  });

  testWidgets('Cancel allows keeping or discarding unsaved changes', (
    tester,
  ) async {
    final repository = FakeWorkoutRepository([]);
    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Unsaved routine');

    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('Add workout plan'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Unsaved routine',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Add workout plan'), findsNothing);
    expect(repository.records, isEmpty);
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

  testWidgets('Failed save preserves the form and allows retry', (
    tester,
  ) async {
    final repository = FakeWorkoutRepository([])..failWrites = true;

    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Retry routine');

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text('Add workout plan'), findsOneWidget);
    expect(repository.records, isEmpty);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Retry routine',
    );

    repository.failWrites = false;

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.records.single.title, 'Retry routine');
    expect(repository.createCalls, 2);
    expect(find.text('Add workout plan'), findsNothing);
  });

  testWidgets('Pending save blocks another write and back navigation', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeWorkoutRepository([])..createGate = gate;

    await openApp(tester, repository);
    await openAddForm(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Single-save routine',
    );

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
    expect(repository.createCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(repository.records.length, 1);
    expect(find.text('Add workout plan'), findsNothing);
  });

  testWidgets(
    'Successful write with failed refresh does not invite a duplicate',
    (tester) async {
      final repository = FakeWorkoutRepository([])..failReadsAfterWrite = true;

      final controller = await openApp(tester, repository);
      await openAddForm(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Saved routine');

      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.records.length, 1);
      expect(find.text('Add workout plan'), findsNothing);
      expect(find.text(controller.error!), findsOneWidget);

      repository.failReads = false;

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Saved routine'), findsOneWidget);
      expect(repository.createCalls, 1);
    },
  );
}
