class TrainingSummary {
  final DateTime generatedAtUtc;
  final int completedSessions;
  final int unfinishedSessions;
  final int totalSets;
  final int totalRepetitions;

  TrainingSummary({
    required DateTime generatedAtUtc,
    required this.completedSessions,
    required this.unfinishedSessions,
    required this.totalSets,
    required this.totalRepetitions,
  }) : generatedAtUtc = generatedAtUtc.toUtc() {
    if (completedSessions < 0 ||
        unfinishedSessions < 0 ||
        totalSets < 0 ||
        totalRepetitions < 0) {
      throw ArgumentError('Summary totals cannot be negative.');
    }

    if (completedSessions + unfinishedSessions > totalSets ||
        totalRepetitions < totalSets) {
      throw ArgumentError('Summary totals are inconsistent.');
    }
  }

  Map<String, Object?> toMap() {
    return {
      'version': 1,
      'generatedAtUtc': generatedAtUtc.toIso8601String(),
      'completedSessions': completedSessions,
      'unfinishedSessions': unfinishedSessions,
      'totalSets': totalSets,
      'totalRepetitions': totalRepetitions,
    };
  }

  factory TrainingSummary.fromMap(Map<String, Object?> map) {
    if (map['version'] is! int ||
        map['version'] != 1 ||
        map['generatedAtUtc'] is! String ||
        map['completedSessions'] is! int ||
        map['unfinishedSessions'] is! int ||
        map['totalSets'] is! int ||
        map['totalRepetitions'] is! int) {
      throw const FormatException('Invalid or unsupported summary.');
    }

    final generatedAt = DateTime.tryParse(map['generatedAtUtc'] as String);

    if (generatedAt == null || !generatedAt.isUtc) {
      throw const FormatException('Invalid summary timestamp.');
    }

    try {
      return TrainingSummary(
        generatedAtUtc: generatedAt,
        completedSessions: map['completedSessions'] as int,
        unfinishedSessions: map['unfinishedSessions'] as int,
        totalSets: map['totalSets'] as int,
        totalRepetitions: map['totalRepetitions'] as int,
      );
    } on ArgumentError {
      throw const FormatException('Invalid summary totals.');
    }
  }
}
