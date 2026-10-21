import '../models/training_log.dart';

abstract class TrainingLogRepository {
  Future<List<TrainingLog>> getLogs({int? workoutId});

  Future<TrainingLog?> getLog(int id);

  Future<TrainingLog> createLog(TrainingLog log);

  Future<TrainingLog> updateLog(TrainingLog log);

  Future<void> deleteLog(int id);

  Future<void> updateSession({
    required int workoutId,
    required String sessionKey,
    required String sessionLabel,
    required bool sessionFinished,
  });

  Future<int> deleteUnfinishedSession({
    required int workoutId,
    required String sessionKey,
  });

  Future<int> countFinishedSessions({int? workoutId});
}
