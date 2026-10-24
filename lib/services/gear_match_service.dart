import '../models/training_log.dart';
import '../models/training_session.dart';
import '../models/workout_plan.dart';

class GearMatchResult {
  final WorkoutPlan plan;
  final int score;
  final String reason;

  const GearMatchResult({
    required this.plan,
    required this.score,
    required this.reason,
  });
}

class GearMatchService {
  GearMatchResult? recommend({
    required List<WorkoutPlan> plans,
    required List<TrainingLog> logs,
    required String? equipmentPreference,
  }) {
    _validateInputs(plans, equipmentPreference);

    final completed = TrainingSession.groupLogs(logs)
        .where((session) => session.sessionFinished)
        .toList();

    if (plans.isEmpty) return null;

    final recentWorkoutId = completed.isEmpty
        ? null
        : completed.first.workoutId;

    final ordered = List<WorkoutPlan>.of(plans)
      ..sort((a, b) => a.id!.compareTo(b.id!));

    WorkoutPlan? selected;
    var selectedScore = -1;

    for (final plan in ordered) {
      var score = 0;

      if (equipmentPreference != null &&
          plan.equipmentTag == equipmentPreference) {
        score += 2;
      }

      if (recentWorkoutId != null && plan.id != recentWorkoutId) {
        score += 1;
      }

      if (score > selectedScore) {
        selected = plan;
        selectedScore = score;
      }
    }

    final plan = selected!;
    final reasons = <String>[];

    if (equipmentPreference == null) {
      reasons.add('No equipment preference is set.');
    } else if (plan.equipmentTag == equipmentPreference) {
      reasons.add('Matches your equipment preference (+2).');
    } else {
      reasons.add('Does not match your equipment preference (+0).');
    }

    if (recentWorkoutId == null) {
      reasons.add('No completed session is available for comparison.');
    } else if (plan.id != recentWorkoutId) {
      reasons.add(
        'Differs from your most recently completed session’s plan (+1).',
      );
    } else {
      reasons.add(
        'Uses the same plan as your most recently completed session (+0).',
      );
    }

    reasons.add('Equal scores use the lowest plan ID.');

    return GearMatchResult(
      plan: plan,
      score: selectedScore,
      reason: reasons.join(' '),
    );
  }

  GearMatchResult? baseline({
    required List<WorkoutPlan> plans,
    required String? equipmentPreference,
  }) {
    _validateInputs(plans, equipmentPreference);

    if (plans.isEmpty) return null;

    final ordered = List<WorkoutPlan>.of(plans)
      ..sort((a, b) => a.id!.compareTo(b.id!));

    WorkoutPlan? selected;
    var selectedScore = -1;

    for (final plan in ordered) {
      final score =
          equipmentPreference != null &&
              plan.equipmentTag == equipmentPreference
          ? 2
          : 0;

      if (score > selectedScore) {
        selected = plan;
        selectedScore = score;
      }
    }

    return GearMatchResult(
      plan: selected!,
      score: selectedScore,
      reason:
          'Equipment-only baseline. '
          'Matching equipment earns two points. '
          'Equal scores use the lowest plan ID.',
    );
  }

  void _validateInputs(List<WorkoutPlan> plans, String? equipmentPreference) {
    if (equipmentPreference != null &&
        !WorkoutPlan.equipmentTags.contains(equipmentPreference)) {
      throw ArgumentError('Choose a valid equipment preference.');
    }

    final ids = <int>{};

    for (final plan in plans) {
      final id = plan.id;

      if (id == null) {
        throw ArgumentError('Gear Match requires saved workout plans.');
      }

      if (!ids.add(id)) {
        throw ArgumentError('Workout plan IDs must be unique.');
      }
    }
  }
}
