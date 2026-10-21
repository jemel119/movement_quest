import '../models/workout_plan.dart';

abstract class WorkoutRepository {
  Future<List<WorkoutPlan>> getPlans({String? equipmentTag});

  Future<WorkoutPlan?> getPlan(int id);

  Future<WorkoutPlan> createPlan(WorkoutPlan plan);

  Future<WorkoutPlan> updatePlan(WorkoutPlan plan);

  Future<void> deletePlan(int id);
}
