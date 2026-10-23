import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/preferences_controller.dart';
import 'package:movement_quest/controllers/workout_controller.dart';
import 'package:movement_quest/models/app_preferences.dart';
import 'package:movement_quest/models/workout_plan.dart';
import 'package:movement_quest/repositories/preferences_repository.dart';
import 'package:movement_quest/repositories/training_log_repository.dart';
import 'package:movement_quest/repositories/workout_repository.dart';
import 'package:movement_quest/screens/workout_editor_screen.dart';
import 'package:provider/provider.dart';

class EditorPreferencesRepository implements PreferencesRepository {
  AppPreferences stored;

  EditorPreferencesRepository(this.stored);

  @override
  Future<AppPreferences> load() async => stored;

  @override
  Future<void> save(AppPreferences preferences) async {
    stored = preferences;
  }
}

class EditorWorkoutRepository extends Fake implements WorkoutRepository {
  final List<WorkoutPlan> records = [];

  @override
  Future<List<WorkoutPlan>> getPlans({String? equipmentTag}) async {
    return records
        .where(
          (plan) => equipmentTag == null || plan.equipmentTag == equipmentTag,
        )
        .toList();
  }

  @override
  Future<WorkoutPlan> createPlan(WorkoutPlan plan) async {
    final saved = plan.copyWith(id: records.length + 1);
    records.add(saved);
    return saved;
  }

  @override
  Future<WorkoutPlan> updatePlan(WorkoutPlan plan) async {
    final index = records.indexWhere((record) => record.id == plan.id);

    if (index == -1) {
      throw StateError('Workout plan not found.');
    }

    records[index] = plan;
    return plan;
  }
}

class EditorTrainingLogRepository extends Fake
    implements TrainingLogRepository {
  @override
  Future<int> countFinishedSessions({int? workoutId}) async => 0;
}

void main() {
  Future<EditorWorkoutRepository> openEditor(
    WidgetTester tester, {
    required int defaultEffort,
    WorkoutPlan? plan,
    bool preloadPreferences = true,
  }) async {
    final repository = EditorWorkoutRepository();

    if (plan != null) {
      repository.records.add(plan);
    }

    final workoutController = WorkoutController(
      repository,
      EditorTrainingLogRepository(),
    );

    final preferencesController = PreferencesController(
      EditorPreferencesRepository(AppPreferences(defaultEffort: defaultEffort)),
    );

    addTearDown(workoutController.dispose);
    addTearDown(preferencesController.dispose);

    await workoutController.load();

    if (preloadPreferences) {
      await preferencesController.load();
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutController>.value(
            value: workoutController,
          ),
          ChangeNotifierProvider<PreferencesController>.value(
            value: preferencesController,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => WorkoutEditorScreen(plan: plan),
                      ),
                    );
                  },
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    return repository;
  }

  Future<void> saveForm(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Save plan');

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('A new plan uses and saves the preferred default effort', (
    tester,
  ) async {
    final repository = await openEditor(tester, defaultEffort: 5);

    expect(find.text('Effort preference: 5 of 5'), findsOneWidget);

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 5);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Preferred effort routine',
    );

    await saveForm(tester);

    expect(repository.records, hasLength(1));
    expect(repository.records.single.effortPreference, 5);
    expect(find.text('Add workout plan'), findsNothing);
    expect(find.text('Open editor'), findsOneWidget);
  });

  testWidgets('Editing preserves the plan effort instead of the default', (
    tester,
  ) async {
    final repository = await openEditor(
      tester,
      defaultEffort: 5,
      plan: WorkoutPlan(
        id: 7,
        title: 'Existing routine',
        equipmentTag: 'Band',
        effortPreference: 2,
      ),
    );

    expect(find.text('Effort preference: 2 of 5'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Updated routine');

    await saveForm(tester);

    expect(repository.records, hasLength(1));
    expect(repository.records.single.id, 7);
    expect(repository.records.single.title, 'Updated routine');
    expect(repository.records.single.effortPreference, 2);
  });

  testWidgets('An unchanged default does not trigger discard confirmation', (
    tester,
  ) async {
    final repository = await openEditor(tester, defaultEffort: 4);

    expect(find.text('Effort preference: 4 of 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Add workout plan'), findsNothing);
    expect(find.text('Open editor'), findsOneWidget);
    expect(repository.records, isEmpty);
  });

  testWidgets('The editor loads preferences when they are not preloaded', (
    tester,
  ) async {
    await openEditor(tester, defaultEffort: 1, preloadPreferences: false);

    expect(find.text('Effort preference: 1 of 5'), findsOneWidget);

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 1);
  });
}
