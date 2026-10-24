import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/preferences_controller.dart';
import 'package:movement_quest/models/app_preferences.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/models/workout_plan.dart';
import 'package:movement_quest/repositories/preferences_repository.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';
import 'package:movement_quest/repositories/workout_repository.dart';
import 'package:movement_quest/widgets/gear_match_panel.dart';
import 'package:provider/provider.dart';

class GearMatchWorkoutRepository extends Fake implements WorkoutRepository {
  final List<WorkoutPlan> records;

  bool failReads = false;

  GearMatchWorkoutRepository(this.records);

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
}

class GearMatchLogRepository extends Fake implements TrainingLogRepository {
  final List<TrainingLog> records;

  GearMatchLogRepository([this.records = const []]);

  @override
  Future<List<TrainingLog>> getLogs({int? workoutId}) async {
    return records
        .where((log) => workoutId == null || log.workoutId == workoutId)
        .toList();
  }
}

class GearMatchPreferencesRepository implements PreferencesRepository {
  AppPreferences stored = AppPreferences(equipmentPreference: 'Band');

  bool failLoads = false;

  @override
  Future<AppPreferences> load() async {
    if (failLoads) {
      throw Exception('Load failed.');
    }

    return stored;
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    stored = preferences;
  }
}

void main() {
  List<WorkoutPlan> examplePlans() {
    return [
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
    ];
  }

  Future<void> openPanel(
    WidgetTester tester, {
    required GearMatchWorkoutRepository workouts,
    GearMatchLogRepository? logs,
    GearMatchPreferencesRepository? preferences,
    ValueChanged<WorkoutPlan>? onViewPlan,
    bool enabled = true,
  }) async {
    final controller = PreferencesController(
      preferences ?? GearMatchPreferencesRepository(),
    );

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutRepository>.value(value: workouts),
          Provider<TrainingLogRepository>.value(
            value: logs ?? GearMatchLogRepository(),
          ),
          ChangeNotifierProvider<PreferencesController>.value(
            value: controller,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                GearMatchPanel(
                  enabled: enabled,
                  onViewPlan: onViewPlan ?? (_) {},
                ),
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

  Future<void> requestRecommendation(WidgetTester tester) {
    return tapControl(tester, find.widgetWithText(FilledButton, 'Find a plan'));
  }

  testWidgets('A recommendation includes the plan score and explanation', (
    tester,
  ) async {
    await openPanel(
      tester,
      workouts: GearMatchWorkoutRepository(examplePlans()),
    );

    expect(find.text('Suggested plan: Band routine'), findsNothing);

    await requestRecommendation(tester);

    expect(find.text('Suggested plan: Band routine'), findsOneWidget);
    expect(find.text('Rule score: 2 of 3'), findsOneWidget);
    expect(
      find.textContaining('Matches your equipment preference (+2).'),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('View plan'), findsOneWidget);
  });

  testWidgets('Not now dismisses the suggestion without viewing a plan', (
    tester,
  ) async {
    final viewedPlans = <WorkoutPlan>[];
    final workouts = GearMatchWorkoutRepository(examplePlans());

    await openPanel(tester, workouts: workouts, onViewPlan: viewedPlans.add);

    await requestRecommendation(tester);

    await tapControl(tester, find.widgetWithText(TextButton, 'Not now'));

    expect(find.text('Suggested plan: Band routine'), findsNothing);
    expect(find.text('Not now'), findsNothing);
    expect(viewedPlans, isEmpty);
    expect(workouts.records, hasLength(2));
    expect(find.text('Find a plan'), findsOneWidget);
  });

  testWidgets('View plan passes the selected plan to the callback', (
    tester,
  ) async {
    final viewedPlans = <WorkoutPlan>[];

    await openPanel(
      tester,
      workouts: GearMatchWorkoutRepository(examplePlans()),
      onViewPlan: viewedPlans.add,
    );

    await requestRecommendation(tester);

    await tapControl(tester, find.widgetWithText(TextButton, 'View plan'));

    expect(viewedPlans, hasLength(1));
    expect(viewedPlans.single.id, 2);
    expect(viewedPlans.single.title, 'Band routine');
    expect(find.text('Suggested plan: Band routine'), findsNothing);
  });

  testWidgets('An empty catalog gives an actionable message', (tester) async {
    await openPanel(tester, workouts: GearMatchWorkoutRepository([]));

    await requestRecommendation(tester);

    expect(
      find.text('Add a workout plan, then try Gear Match again.'),
      findsOneWidget,
    );
    expect(find.text('View plan'), findsNothing);
    expect(find.text('Not now'), findsNothing);
  });

  testWidgets('A failed repository read can be retried', (tester) async {
    final workouts = GearMatchWorkoutRepository(examplePlans());
    workouts.failReads = true;

    await openPanel(tester, workouts: workouts);

    await requestRecommendation(tester);

    expect(
      find.text('Could not load a recommendation. Try again.'),
      findsOneWidget,
    );
    expect(find.text('View plan'), findsNothing);

    workouts.failReads = false;

    await requestRecommendation(tester);

    expect(find.text('Suggested plan: Band routine'), findsOneWidget);
    expect(
      find.text('Could not load a recommendation. Try again.'),
      findsNothing,
    );
  });

  testWidgets('A preference loading failure is shown and can be retried', (
    tester,
  ) async {
    final preferences = GearMatchPreferencesRepository();
    preferences.failLoads = true;

    await openPanel(
      tester,
      workouts: GearMatchWorkoutRepository(examplePlans()),
      preferences: preferences,
    );

    await requestRecommendation(tester);

    expect(
      find.text('Could not load your preferences. Try again.'),
      findsOneWidget,
    );
    expect(find.text('View plan'), findsNothing);

    preferences.failLoads = false;

    await requestRecommendation(tester);

    expect(find.text('Suggested plan: Band routine'), findsOneWidget);
  });

  testWidgets('Invalid saved plan input produces feedback', (tester) async {
    await openPanel(
      tester,
      workouts: GearMatchWorkoutRepository([
        WorkoutPlan(
          title: 'Unsaved routine',
          equipmentTag: 'Band',
          effortPreference: 3,
        ),
      ]),
    );

    await requestRecommendation(tester);

    expect(
      find.text(
        'Gear Match received invalid input. Check your saved plans '
        'and equipment preference.',
      ),
      findsOneWidget,
    );
    expect(find.text('View plan'), findsNothing);
  });

  testWidgets('Disabled Gear Match cannot request a recommendation', (
    tester,
  ) async {
    await openPanel(
      tester,
      workouts: GearMatchWorkoutRepository(examplePlans()),
      enabled: false,
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Find a plan'),
    );

    expect(button.onPressed, isNull);
    expect(find.text('View plan'), findsNothing);
  });
}
