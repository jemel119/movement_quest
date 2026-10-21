import '../models/workout_plan.dart';
import '../repositories/workout_repository.dart';
import 'app_database.dart';

class SqliteWorkoutRepository implements WorkoutRepository {
  final AppDatabase _database;

  SqliteWorkoutRepository(this._database);

  @override
  Future<List<WorkoutPlan>> getPlans({String? equipmentTag}) async {
    if (equipmentTag != null &&
        !WorkoutPlan.equipmentTags.contains(equipmentTag)) {
      throw ArgumentError('Choose a valid equipment filter.');
    }

    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.workoutPlansTable,
      where: equipmentTag == null ? null : 'equipmentTag = ?',
      whereArgs: equipmentTag == null ? null : [equipmentTag],
      orderBy: 'id ASC',
    );

    return rows.map(WorkoutPlan.fromMap).toList(growable: false);
  }

  @override
  Future<WorkoutPlan?> getPlan(int id) async {
    _validateId(id);

    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.workoutPlansTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : WorkoutPlan.fromMap(rows.first);
  }

  @override
  Future<WorkoutPlan> createPlan(WorkoutPlan plan) async {
    if (plan.id != null) {
      throw ArgumentError('A new workout plan must not have an ID.');
    }

    final db = await _database.database;
    final id = await db.insert(AppDatabase.workoutPlansTable, plan.toMap());

    return plan.copyWith(id: id);
  }

  @override
  Future<WorkoutPlan> updatePlan(WorkoutPlan plan) async {
    final id = plan.id;

    if (id == null) {
      throw ArgumentError('Save the workout plan before updating it.');
    }

    _validateId(id);

    final values = plan.toMap()..remove('id');
    final db = await _database.database;
    final affected = await db.update(
      AppDatabase.workoutPlansTable,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affected == 0) {
      throw StateError('This workout plan no longer exists.');
    }

    return plan;
  }

  @override
  Future<void> deletePlan(int id) async {
    _validateId(id);

    final db = await _database.database;
    final affected = await db.delete(
      AppDatabase.workoutPlansTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affected == 0) {
      throw StateError('This workout plan no longer exists.');
    }
  }

  void _validateId(int id) {
    if (id <= 0) {
      throw ArgumentError('Plan ID must be positive.');
    }
  }
}
