import 'package:sqflite/sqflite.dart';

import '../models/training_log.dart';
import '../repositories/training_log_repository.dart';
import 'app_database.dart';

class SqliteTrainingLogRepository implements TrainingLogRepository {
  final AppDatabase _database;

  SqliteTrainingLogRepository(this._database);

  @override
  Future<List<TrainingLog>> getLogs({int? workoutId}) async {
    if (workoutId != null) {
      _validateId(workoutId);
    }

    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.trainingLogsTable,
      where: workoutId == null ? null : 'workoutId = ?',
      whereArgs: workoutId == null ? null : [workoutId],
      orderBy: 'loggedAt DESC, id DESC',
    );

    return rows.map(TrainingLog.fromMap).toList(growable: false);
  }

  @override
  Future<TrainingLog?> getLog(int id) async {
    _validateId(id);

    final db = await _database.database;
    return _findLog(db, id);
  }

  @override
  Future<TrainingLog> createLog(TrainingLog log) async {
    if (log.id != null) {
      throw ArgumentError('A new training log must not have an ID.');
    }

    final db = await _database.database;

    return db.transaction((txn) async {
      final sessionRows = await txn.query(
        AppDatabase.trainingLogsTable,
        where: 'sessionKey = ?',
        whereArgs: [log.sessionKey],
      );

      for (final row in sessionRows) {
        final existing = TrainingLog.fromMap(row);

        if (existing.workoutId != log.workoutId) {
          throw StateError('This session belongs to another workout.');
        }

        if (existing.sessionLabel != log.sessionLabel ||
            existing.sessionFinished != log.sessionFinished) {
          throw StateError(
            'New sets must match the session label and finish status.',
          );
        }
      }

      final id = await txn.insert(AppDatabase.trainingLogsTable, log.toMap());

      return log.copyWith(id: id);
    });
  }

  @override
  Future<TrainingLog> updateLog(TrainingLog log) async {
    final id = log.id;

    if (id == null) {
      throw ArgumentError('Save the training log before updating it.');
    }

    _validateId(id);

    final db = await _database.database;

    return db.transaction((txn) async {
      final existing = await _findLog(txn, id);

      if (existing == null) {
        throw StateError('This training log no longer exists.');
      }

      if (existing.workoutId != log.workoutId ||
          existing.sessionKey != log.sessionKey ||
          !existing.loggedAt.isAtSameMomentAs(log.loggedAt)) {
        throw ArgumentError(
          'Editing a set must preserve its workout, session, and timestamp.',
        );
      }

      if (existing.sessionLabel != log.sessionLabel ||
          existing.sessionFinished != log.sessionFinished) {
        throw ArgumentError(
          'Use the session controls to change its label or finish status.',
        );
      }

      await txn.update(
        AppDatabase.trainingLogsTable,
        {'exerciseLabel': log.exerciseLabel, 'repetitions': log.repetitions},
        where: 'id = ?',
        whereArgs: [id],
      );

      return log;
    });
  }

  @override
  Future<void> deleteLog(int id) async {
    _validateId(id);

    final db = await _database.database;
    final affected = await db.delete(
      AppDatabase.trainingLogsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affected == 0) {
      throw StateError('This training log no longer exists.');
    }
  }

  @override
  Future<void> updateSession({
    required int workoutId,
    required String sessionKey,
    required String sessionLabel,
    required bool sessionFinished,
  }) async {
    _validateId(workoutId);
    final key = _validateSessionKey(sessionKey);
    final label = sessionLabel.trim();

    if (label.isEmpty) {
      throw ArgumentError('Enter a session label.');
    }

    final db = await _database.database;
    final affected = await db.update(
      AppDatabase.trainingLogsTable,
      {'sessionLabel': label, 'sessionFinished': sessionFinished ? 1 : 0},
      where: 'workoutId = ? AND sessionKey = ?',
      whereArgs: [workoutId, key],
    );

    if (affected == 0) {
      throw StateError('This session has no saved sets.');
    }
  }

  @override
  Future<int> deleteUnfinishedSession({
    required int workoutId,
    required String sessionKey,
  }) async {
    _validateId(workoutId);
    final key = _validateSessionKey(sessionKey);
    final db = await _database.database;

    return db.delete(
      AppDatabase.trainingLogsTable,
      where: '''
        workoutId = ?
        AND sessionKey = ?
        AND sessionFinished = 0
      ''',
      whereArgs: [workoutId, key],
    );
  }

  @override
  Future<int> countFinishedSessions({int? workoutId}) async {
    if (workoutId != null) {
      _validateId(workoutId);
    }

    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(DISTINCT sessionKey)
      FROM ${AppDatabase.trainingLogsTable}
      WHERE sessionFinished = 1
      ${workoutId == null ? '' : 'AND workoutId = ?'}
      ''', workoutId == null ? null : [workoutId]);

    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<TrainingLog?> _findLog(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      AppDatabase.trainingLogsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : TrainingLog.fromMap(rows.first);
  }

  void _validateId(int id) {
    if (id <= 0) {
      throw ArgumentError('Record ID must be positive.');
    }
  }

  String _validateSessionKey(String sessionKey) {
    final key = sessionKey.trim();

    if (key.isEmpty) {
      throw ArgumentError('A session key is required.');
    }

    return key;
  }
}
