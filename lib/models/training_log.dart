class TrainingLog {
  final int? id;
  final int workoutId;
  final String sessionKey;
  final String sessionLabel;
  final String exerciseLabel;
  final int repetitions;
  final DateTime loggedAt;
  final bool sessionFinished;

  TrainingLog({
    this.id,
    required this.workoutId,
    required String sessionKey,
    required String sessionLabel,
    required String exerciseLabel,
    required this.repetitions,
    required DateTime loggedAt,
    this.sessionFinished = false,
  }) : sessionKey = sessionKey.trim(),
       sessionLabel = sessionLabel.trim(),
       exerciseLabel = exerciseLabel.trim(),
       loggedAt = loggedAt.toUtc() {
    if (id != null && id! <= 0) {
      throw ArgumentError('Log ID must be positive.');
    }
    if (workoutId <= 0) {
      throw ArgumentError('Choose a saved workout plan.');
    }
    if (this.sessionKey.isEmpty) {
      throw ArgumentError('A session key is required.');
    }
    if (this.sessionLabel.isEmpty) {
      throw ArgumentError('Enter a session label.');
    }
    if (this.exerciseLabel.isEmpty) {
      throw ArgumentError('Enter an exercise label.');
    }
    if (repetitions <= 0) {
      throw ArgumentError('Enter a positive whole number of repetitions.');
    }
  }

  TrainingLog copyWith({
    int? id,
    String? sessionLabel,
    String? exerciseLabel,
    int? repetitions,
    bool? sessionFinished,
  }) {
    return TrainingLog(
      id: id ?? this.id,
      workoutId: workoutId,
      sessionKey: sessionKey,
      sessionLabel: sessionLabel ?? this.sessionLabel,
      exerciseLabel: exerciseLabel ?? this.exerciseLabel,
      repetitions: repetitions ?? this.repetitions,
      loggedAt: loggedAt,
      sessionFinished: sessionFinished ?? this.sessionFinished,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'workoutId': workoutId,
      'sessionKey': sessionKey,
      'sessionLabel': sessionLabel,
      'exerciseLabel': exerciseLabel,
      'repetitions': repetitions,
      'loggedAt': loggedAt.toIso8601String(),
      'sessionFinished': sessionFinished ? 1 : 0,
    };
  }

  factory TrainingLog.fromMap(Map<String, Object?> map) {
    final finished = map['sessionFinished'];

    if (finished != 0 && finished != 1) {
      throw const FormatException('Invalid session finish status.');
    }

    return TrainingLog(
      id: map['id'] as int?,
      workoutId: map['workoutId'] as int,
      sessionKey: map['sessionKey'] as String,
      sessionLabel: map['sessionLabel'] as String,
      exerciseLabel: map['exerciseLabel'] as String,
      repetitions: map['repetitions'] as int,
      loggedAt: DateTime.parse(map['loggedAt'] as String),
      sessionFinished: finished == 1,
    );
  }
}
