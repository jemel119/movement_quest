import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/workout_plan.dart';
import 'package:movement_quest/repositories/workout_repository.dart';
import 'package:movement_quest/screens/workout_detail_screen.dart';
import 'package:provider/provider.dart';

class DetailWorkoutRepository extends Fake implements WorkoutRepository {
  WorkoutPlan? plan;

  bool failReads = false;

  final requestedIds = <int>[];

  DetailWorkoutRepository({this.plan});

  @override
  Future<WorkoutPlan?> getPlan(int id) async {
    requestedIds.add(id);

    if (failReads) {
      throw Exception('Read failed.');
    }

    return plan?.id == id ? plan : null;
  }
}

void main() {
  Future<void> openDetails(
    WidgetTester tester,
    DetailWorkoutRepository repository, {
    int workoutId = 7,
  }) async {
    await tester.pumpWidget(
      Provider<WorkoutRepository>.value(
        value: repository,
        child: MaterialApp(home: WorkoutDetailScreen(workoutId: workoutId)),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Details loads the requested plan and displays its values', (
    tester,
  ) async {
    final repository = DetailWorkoutRepository(
      plan: WorkoutPlan(
        id: 7,
        title: 'Band routine',
        equipmentTag: 'Band',
        planNote: 'My selected exercises',
        effortPreference: 4,
      ),
    );

    await openDetails(tester, repository);

    expect(repository.requestedIds, [7]);
    expect(find.text('Workout details'), findsOneWidget);
    expect(find.text('Band routine'), findsOneWidget);
    expect(find.text('Equipment: Band'), findsOneWidget);
    expect(find.text('Effort preference: 4 of 5'), findsOneWidget);
    expect(find.text('My selected exercises'), findsOneWidget);
    expect(find.text('Edit plan'), findsOneWidget);
  });

  testWidgets('An empty plan note shows the fallback message', (tester) async {
    final repository = DetailWorkoutRepository(
      plan: WorkoutPlan(
        id: 7,
        title: 'Simple routine',
        equipmentTag: 'None',
        effortPreference: 2,
      ),
    );

    await openDetails(tester, repository);

    expect(find.text('No plan note added.'), findsOneWidget);
    expect(find.text('Simple routine'), findsOneWidget);
  });

  testWidgets('A missing plan shows a message without editing controls', (
    tester,
  ) async {
    final repository = DetailWorkoutRepository();

    await openDetails(tester, repository);

    expect(find.text('This workout plan no longer exists.'), findsOneWidget);
    expect(find.text('Edit plan'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('A failed read can be retried successfully', (tester) async {
    final repository = DetailWorkoutRepository(
      plan: WorkoutPlan(
        id: 7,
        title: 'Recovered routine',
        equipmentTag: 'Dumbbells',
        effortPreference: 3,
      ),
    );

    repository.failReads = true;

    await openDetails(tester, repository);

    expect(
      find.text('Could not load this workout. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Edit plan'), findsNothing);
    expect(repository.requestedIds, [7]);

    repository.failReads = false;

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.requestedIds, [7, 7]);
    expect(find.text('Recovered routine'), findsOneWidget);
    expect(find.text('Edit plan'), findsOneWidget);
    expect(find.text('Could not load this workout. Try again.'), findsNothing);
  });
}
