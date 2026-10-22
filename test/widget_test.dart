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

  FakeWorkoutRepository(this.records);

  @override
  Future<List<WorkoutPlan>> getPlans({String? equipmentTag}) async {
    return records
        .where(
          (plan) => equipmentTag == null || plan.equipmentTag == equipmentTag,
        )
        .toList();
  }
}

class FakeTrainingLogRepository extends Fake implements TrainingLogRepository {
  @override
  Future<int> countFinishedSessions({int? workoutId}) async => 2;
}

void main() {
  Future<WorkoutController> prepareController(
    WidgetTester tester, {
    List<WorkoutPlan>? records,
  }) async {
    final controller = WorkoutController(
      FakeWorkoutRepository(
        records ??
            [
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
            ],
      ),
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

  testWidgets('Navigation opens each main section', (tester) async {
    await prepareController(tester);

    expect(find.text('Movement Quest'), findsOneWidget);
    expect(find.text('Completed sessions: 2'), findsOneWidget);
    expect(find.text('No-equipment routine'), findsOneWidget);

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
    await prepareController(tester);

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
    await prepareController(tester, records: []);

    expect(find.text('No workout plans yet.'), findsOneWidget);
  });
}
