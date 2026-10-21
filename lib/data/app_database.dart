import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const fileName = 'movement_quest.db';
  static const version = 1;
  static const workoutPlansTable = 'workout_plans';
  static const trainingLogsTable = 'training_logs';

  Future<Database>? _databaseFuture;

  Future<Database> get database async {
    final pending = _databaseFuture ??= _open();

    try {
      return await pending;
    } catch (_) {
      if (identical(_databaseFuture, pending)) {
        _databaseFuture = null;
      }
      rethrow;
    }
  }

  Future<Database> _open() async {
    final directory = await getDatabasesPath();

    return openDatabase(
      path.join(directory, fileName),
      version: version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $workoutPlansTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL
          CHECK(length(trim(title)) > 0),
        equipmentTag TEXT NOT NULL
          CHECK(equipmentTag IN ('None', 'Dumbbells', 'Band')),
        planNote TEXT NOT NULL DEFAULT '',
        effortPreference INTEGER NOT NULL
          CHECK(
            typeof(effortPreference) = 'integer'
            AND effortPreference BETWEEN 1 AND 5
          )
      )
    ''');

    await db.execute('''
      CREATE TABLE $trainingLogsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER NOT NULL,
        sessionKey TEXT NOT NULL
          CHECK(length(trim(sessionKey)) > 0),
        sessionLabel TEXT NOT NULL
          CHECK(length(trim(sessionLabel)) > 0),
        exerciseLabel TEXT NOT NULL
          CHECK(length(trim(exerciseLabel)) > 0),
        repetitions INTEGER NOT NULL
          CHECK(
            typeof(repetitions) = 'integer'
            AND repetitions > 0
          ),
        loggedAt TEXT NOT NULL
          CHECK(length(trim(loggedAt)) > 0),
        sessionFinished INTEGER NOT NULL DEFAULT 0
          CHECK(sessionFinished IN (0, 1)),
        FOREIGN KEY(workoutId)
          REFERENCES $workoutPlansTable(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_training_logs_workout_session
      ON $trainingLogsTable(workoutId, sessionKey)
    ''');
  }

  Future<void> close() async {
    final pending = _databaseFuture;

    if (pending == null) {
      return;
    }

    try {
      final db = await pending;
      await db.close();
    } finally {
      if (identical(_databaseFuture, pending)) {
        _databaseFuture = null;
      }
    }
  }
}
