import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/models/workout_plan.dart';
import 'package:movement_quest/services/gear_match_service.dart';

void main() {
  final service = GearMatchService();

  WorkoutPlan plan(int id, {String equipment = 'Band'}) {
    return WorkoutPlan(
      id: id,
      title: 'Plan $id',
      equipmentTag: equipment,
      effortPreference: 3,
    );
  }

  TrainingLog log({
    required int id,
    required int workoutId,
    String key = 'completed-session',
    int hour = 10,
    bool finished = true,
  }) {
    return TrainingLog(
      id: id,
      workoutId: workoutId,
      sessionKey: key,
      sessionLabel: key,
      exerciseLabel: 'Exercise $id',
      repetitions: 8,
      loggedAt: DateTime.utc(2026, 10, 24, hour),
      sessionFinished: finished,
    );
  }

  group('GearMatchService', () {
    test('Equipment match and different recent plan earn three points', () {
      final result = service.recommend(
        plans: [
          plan(1, equipment: 'None'),
          plan(2),
        ],
        logs: [log(id: 1, workoutId: 1)],
        equipmentPreference: 'Band',
      );

      expect(result!.plan.id, 2);
      expect(result.score, 3);
      expect(
        result.reason,
        contains('Matches your equipment preference (+2).'),
      );
      expect(result.reason, contains('completed session’s plan (+1).'));
    });

    test('Equipment matching outweighs the different-plan bonus', () {
      final result = service.recommend(
        plans: [
          plan(1),
          plan(2, equipment: 'None'),
        ],
        logs: [log(id: 1, workoutId: 1)],
        equipmentPreference: 'Band',
      );

      expect(result!.plan.id, 1);
      expect(result.score, 2);
    });

    test('Empty plans return no recommendation or baseline choice', () {
      expect(
        service.recommend(plans: [], logs: [], equipmentPreference: null),
        isNull,
      );

      expect(service.baseline(plans: [], equipmentPreference: null), isNull);
    });

    test('Missing history omits the different-plan bonus', () {
      final result = service.recommend(
        plans: [plan(2), plan(1)],
        logs: [],
        equipmentPreference: 'Band',
      );

      expect(result!.plan.id, 1);
      expect(result.score, 2);
      expect(
        result.reason,
        contains('No completed session is available for comparison.'),
      );
    });

    test('Missing equipment preference omits equipment points', () {
      final result = service.recommend(
        plans: [
          plan(1),
          plan(2, equipment: 'None'),
        ],
        logs: [log(id: 1, workoutId: 1)],
        equipmentPreference: null,
      );

      expect(result!.plan.id, 2);
      expect(result.score, 1);
      expect(result.reason, contains('No equipment preference is set.'));
    });

    test('Missing preference and history use the lowest ID at zero points', () {
      final result = service.recommend(
        plans: [
          plan(9),
          plan(3, equipment: 'None'),
          plan(6, equipment: 'Dumbbells'),
        ],
        logs: [],
        equipmentPreference: null,
      );

      expect(result!.plan.id, 3);
      expect(result.score, 0);
    });

    test('No-equipment preference is a real equipment match', () {
      final result = service.recommend(
        plans: [
          plan(1),
          plan(2, equipment: 'None'),
        ],
        logs: [],
        equipmentPreference: 'None',
      );

      expect(result!.plan.id, 2);
      expect(result.score, 2);
    });

    test(
      'Equal scores use ascending plan IDs without changing input order',
      () {
        final plans = [plan(8), plan(2), plan(5)];

        final result = service.recommend(
          plans: plans,
          logs: [],
          equipmentPreference: 'Band',
        );

        expect(result!.plan.id, 2);
        expect(plans.map((item) => item.id).toList(), [8, 2, 5]);
      },
    );

    test('A single available plan can still be recommended', () {
      final result = service.recommend(
        plans: [plan(7)],
        logs: [log(id: 1, workoutId: 7)],
        equipmentPreference: 'Band',
      );

      expect(result!.plan.id, 7);
      expect(result.score, 2);
    });

    test('The recent session uses the latest timestamp across its sets', () {
      final result = service.recommend(
        plans: [plan(1), plan(2)],
        logs: [
          log(id: 1, workoutId: 1, key: 'session-one', hour: 8),
          log(id: 2, workoutId: 2, key: 'session-two', hour: 10),
          log(id: 3, workoutId: 1, key: 'session-one', hour: 12),
        ],
        equipmentPreference: 'Band',
      );

      expect(result!.plan.id, 2);
      expect(result.score, 3);
    });

    test('Equal recent-session timestamps use ascending session keys', () {
      final result = service.recommend(
        plans: [plan(1), plan(2)],
        logs: [
          log(id: 1, workoutId: 2, key: 'session-b'),
          log(id: 2, workoutId: 1, key: 'session-a'),
        ],
        equipmentPreference: 'Band',
      );

      expect(result!.plan.id, 2);
      expect(result.score, 3);
    });

    test('A newer unfinished session does not replace completed history', () {
      final result = service.recommend(
        plans: [plan(1), plan(2)],
        logs: [
          log(id: 1, workoutId: 1, key: 'finished', hour: 8),
          log(
            id: 2,
            workoutId: 2,
            key: 'unfinished',
            hour: 12,
            finished: false,
          ),
        ],
        equipmentPreference: 'Band',
      );

      expect(result!.plan.id, 2);
      expect(result.score, 3);
    });

    test('Only unfinished history produces no recent-session bonus', () {
      final result = service.recommend(
        plans: [plan(1), plan(2)],
        logs: [log(id: 1, workoutId: 1, finished: false)],
        equipmentPreference: 'Band',
      );

      expect(result!.plan.id, 1);
      expect(result.score, 2);
    });

    test('Invalid equipment preference is rejected', () {
      expect(
        () => service.recommend(
          plans: [plan(1)],
          logs: [],
          equipmentPreference: 'Barbell',
        ),
        throwsArgumentError,
      );

      expect(
        () =>
            service.baseline(plans: [plan(1)], equipmentPreference: 'Barbell'),
        throwsArgumentError,
      );
    });

    test('Unsaved plans and duplicate IDs are rejected', () {
      final invalidLists = [
        [
          WorkoutPlan(
            title: 'Unsaved plan',
            equipmentTag: 'Band',
            effortPreference: 3,
          ),
        ],
        [plan(1), plan(1, equipment: 'None')],
      ];

      for (final plans in invalidLists) {
        expect(
          () => service.recommend(
            plans: plans,
            logs: [],
            equipmentPreference: null,
          ),
          throwsArgumentError,
        );

        expect(
          () => service.baseline(plans: plans, equipmentPreference: null),
          throwsArgumentError,
        );
      }
    });

    test('Inconsistent history is rejected instead of silently scored', () {
      expect(
        () => service.recommend(
          plans: [plan(1), plan(2)],
          logs: [log(id: 1, workoutId: 1), log(id: 2, workoutId: 2)],
          equipmentPreference: 'Band',
        ),
        throwsStateError,
      );
    });

    test('Baseline uses equipment matching and ascending IDs', () {
      final result = service.baseline(
        plans: [
          plan(9),
          plan(1, equipment: 'None'),
          plan(4),
        ],
        equipmentPreference: 'Band',
      );

      expect(result!.plan.id, 4);
      expect(result.score, 2);
    });

    test('Counterexample: recent history changes the baseline choice', () {
      final plans = [plan(1), plan(2)];

      final baseline = service.baseline(
        plans: plans,
        equipmentPreference: 'Band',
      );

      final recommendation = service.recommend(
        plans: plans,
        logs: [log(id: 1, workoutId: 1)],
        equipmentPreference: 'Band',
      );

      expect(baseline!.plan.id, 1);
      expect(baseline.score, 2);
      expect(recommendation!.plan.id, 2);
      expect(recommendation.score, 3);
    });
  });
}
