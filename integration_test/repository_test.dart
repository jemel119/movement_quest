import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:movement_quest/data/app_database.dart';
import 'package:movement_quest/data/sqlite_training_log_repository.dart';
import 'package:movement_quest/data/sqlite_workout_repository.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/models/workout_plan.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase storage;
  late SqliteWorkoutRepository plans;
  late SqliteTrainingLogRepository logs;
  String? testPath;

  final timestamp = DateTime.utc(2026, 10, 20, 14, 30);

  Future<WorkoutPlan> createPlan({
    String title = 'Example routine',
    String equipmentTag = 'None',
  }) {
    return plans.createPlan(
      WorkoutPlan(
        title: title,
        equipmentTag: equipmentTag,
        effortPreference: 3,
      ),
    );
  }

  TrainingLog makeLog(
    int workoutId, {
    String sessionKey = 'session-001',
    String sessionLabel = 'Example session',
    int repetitions = 8,
    bool finished = false,
  }) {
    return TrainingLog(
      workoutId: workoutId,
      sessionKey: sessionKey,
      sessionLabel: sessionLabel,
      exerciseLabel: 'Example exercise',
      repetitions: repetitions,
      loggedAt: timestamp,
      sessionFinished: finished,
    );
  }

  setUp(() async {
    testPath = null;
    storage = AppDatabase(
      databaseName:
          'movement_quest_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    plans = SqliteWorkoutRepository(storage);
    logs = SqliteTrainingLogRepository(storage);

    final db = await storage.database;
    testPath = db.path;
  });

  tearDown(() async {
    await storage.close();

    final savedPath = testPath;
    if (savedPath != null) {
      await deleteDatabase(savedPath);
    }
  });

  testWidgets('Workout plans support full CRUD', (tester) async {
    final plan = await createPlan();

    expect(plan.id, isNotNull);
    expect((await plans.getPlans()).length, 1);
    expect((await plans.getPlan(plan.id!))!.title, 'Example routine');

    await plans.updatePlan(plan.copyWith(title: 'Corrected routine'));

    expect((await plans.getPlan(plan.id!))!.title, 'Corrected routine');

    await plans.deletePlan(plan.id!);

    expect(await plans.getPlan(plan.id!), isNull);
    expect(await plans.getPlans(), isEmpty);
  });

  testWidgets('Equipment filtering returns matching plans', (tester) async {
    await createPlan(title: 'No equipment');
    final band = await createPlan(title: 'Band routine', equipmentTag: 'Band');

    final filtered = await plans.getPlans(equipmentTag: 'Band');

    expect(filtered.map((plan) => plan.id), [band.id]);
    expect(await plans.getPlans(equipmentTag: 'Dumbbells'), isEmpty);

    await expectLater(
      plans.getPlans(equipmentTag: 'Unknown'),
      throwsArgumentError,
    );
  });

  testWidgets('Training logs support full CRUD', (tester) async {
    final plan = await createPlan();
    final log = await logs.createLog(makeLog(plan.id!));

    expect(log.id, isNotNull);
    expect((await logs.getLog(log.id!))!.repetitions, 8);

    await logs.updateLog(
      log.copyWith(exerciseLabel: 'Corrected exercise', repetitions: 10),
    );

    final updated = await logs.getLog(log.id!);

    expect(updated!.exerciseLabel, 'Corrected exercise');
    expect(updated.repetitions, 10);
    expect(updated.sessionKey, log.sessionKey);
    expect(updated.loggedAt, timestamp);

    await logs.deleteLog(log.id!);

    expect(await logs.getLog(log.id!), isNull);
    expect(await logs.getLogs(workoutId: plan.id!), isEmpty);
  });

  testWidgets('Missing records produce update and delete failures', (
    tester,
  ) async {
    final plan = await createPlan();
    final log = await logs.createLog(makeLog(plan.id!));

    await logs.deleteLog(log.id!);

    await expectLater(logs.updateLog(log), throwsStateError);
    await expectLater(logs.deleteLog(log.id!), throwsStateError);

    await plans.deletePlan(plan.id!);

    await expectLater(plans.updatePlan(plan), throwsStateError);
    await expectLater(plans.deletePlan(plan.id!), throwsStateError);
  });

  testWidgets('Session keys cannot span different workouts', (tester) async {
    final first = await createPlan(title: 'First plan');
    final second = await createPlan(title: 'Second plan');

    await logs.createLog(makeLog(first.id!));

    await expectLater(logs.createLog(makeLog(second.id!)), throwsStateError);

    expect((await logs.getLogs()).length, 1);
  });

  testWidgets('New sets must match existing session metadata', (tester) async {
    final plan = await createPlan();
    await logs.createLog(makeLog(plan.id!));

    await expectLater(
      logs.createLog(makeLog(plan.id!, sessionLabel: 'Different label')),
      throwsStateError,
    );

    await expectLater(
      logs.createLog(makeLog(plan.id!, finished: true)),
      throwsStateError,
    );

    expect((await logs.getLogs()).length, 1);
  });

  testWidgets('Finishing a session updates every set without duplicates', (
    tester,
  ) async {
    final plan = await createPlan();

    for (var index = 0; index < 3; index++) {
      await logs.createLog(makeLog(plan.id!));
    }

    expect(await logs.countFinishedSessions(), 0);

    for (var attempt = 0; attempt < 2; attempt++) {
      await logs.updateSession(
        workoutId: plan.id!,
        sessionKey: 'session-001',
        sessionLabel: 'Finished session',
        sessionFinished: true,
      );
    }

    final saved = await logs.getLogs();

    expect(saved.length, 3);
    expect(saved.every((log) => log.sessionFinished), isTrue);
    expect(
      saved.every((log) => log.sessionLabel == 'Finished session'),
      isTrue,
    );
    expect(await logs.countFinishedSessions(), 1);
  });

  testWidgets('Deleting sets recomputes the completed-session count', (
    tester,
  ) async {
    final plan = await createPlan();
    final saved = <TrainingLog>[];

    for (var index = 0; index < 3; index++) {
      saved.add(await logs.createLog(makeLog(plan.id!, finished: true)));
    }

    expect(await logs.countFinishedSessions(), 1);

    await logs.deleteLog(saved.first.id!);
    expect(await logs.countFinishedSessions(), 1);

    await logs.deleteLog(saved[1].id!);
    await logs.deleteLog(saved[2].id!);

    expect(await logs.countFinishedSessions(), 0);
  });

  testWidgets('Session counts remain separate across workout plans', (
    tester,
  ) async {
    final first = await createPlan(title: 'First plan');
    final second = await createPlan(title: 'Second plan');

    await logs.createLog(
      makeLog(first.id!, sessionKey: 'first-session', finished: true),
    );
    await logs.createLog(
      makeLog(second.id!, sessionKey: 'second-session', finished: true),
    );

    expect(await logs.countFinishedSessions(), 2);
    expect(await logs.countFinishedSessions(workoutId: first.id!), 1);
    expect(await logs.countFinishedSessions(workoutId: second.id!), 1);
    expect((await logs.getLogs(workoutId: first.id!)).length, 1);
  });

  testWidgets('Reset deletion preserves finished history', (tester) async {
    final plan = await createPlan();

    await logs.createLog(
      makeLog(plan.id!, sessionKey: 'finished-session', finished: true),
    );
    await logs.createLog(makeLog(plan.id!, sessionKey: 'active-session'));

    final removed = await logs.deleteUnfinishedSession(
      workoutId: plan.id!,
      sessionKey: 'active-session',
    );

    expect(removed, 1);
    expect((await logs.getLogs()).single.sessionKey, 'finished-session');
    expect(await logs.countFinishedSessions(), 1);

    expect(
      await logs.deleteUnfinishedSession(
        workoutId: plan.id!,
        sessionKey: 'finished-session',
      ),
      0,
    );
  });

  testWidgets('Foreign keys reject orphan logs and cascade deletion', (
    tester,
  ) async {
    final plan = await createPlan();
    await logs.createLog(makeLog(plan.id!, finished: true));

    await expectLater(
      logs.createLog(makeLog(plan.id! + 1000, sessionKey: 'orphan-session')),
      throwsA(isA<DatabaseException>()),
    );

    await plans.deletePlan(plan.id!);

    expect(await logs.getLogs(), isEmpty);
    expect(await logs.countFinishedSessions(), 0);
  });

  testWidgets('SQLite rejects invalid values even outside the models', (
    tester,
  ) async {
    final plan = await createPlan();
    final db = await storage.database;

    await expectLater(
      db.insert(AppDatabase.trainingLogsTable, {
        ...makeLog(plan.id!).toMap(),
        'repetitions': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );

    await expectLater(
      db.insert(AppDatabase.workoutPlansTable, {
        'title': 'Invalid plan',
        'equipmentTag': 'None',
        'planNote': '',
        'effortPreference': 6,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  testWidgets('Plans and logs survive closing and reopening the database', (
    tester,
  ) async {
    final plan = await createPlan();
    await logs.createLog(makeLog(plan.id!, finished: true));

    final databaseName = storage.databaseName;
    await storage.close();

    storage = AppDatabase(databaseName: databaseName);
    plans = SqliteWorkoutRepository(storage);
    logs = SqliteTrainingLogRepository(storage);

    expect((await plans.getPlan(plan.id!))!.title, plan.title);
    expect((await logs.getLogs()).single.loggedAt, timestamp);
    expect(await logs.countFinishedSessions(), 1);

    await plans.deletePlan(plan.id!);
    await storage.close();

    storage = AppDatabase(databaseName: databaseName);
    plans = SqliteWorkoutRepository(storage);
    logs = SqliteTrainingLogRepository(storage);

    expect(await plans.getPlans(), isEmpty);
    expect(await logs.getLogs(), isEmpty);
  });
}
