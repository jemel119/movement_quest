class ReminderSchedule {
  final int hour;
  final int minute;
  final String timezoneId;

  ReminderSchedule({
    required this.hour,
    required this.minute,
    required this.timezoneId,
  }) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Choose a valid reminder time.');
    }

    if (timezoneId.trim().isEmpty) {
      throw ArgumentError('A reminder timezone is required.');
    }
  }

  Map<String, Object?> toMap() {
    return {
      'version': 1,
      'hour': hour,
      'minute': minute,
      'timezoneId': timezoneId,
    };
  }

  factory ReminderSchedule.fromMap(Map<String, Object?> map) {
    if (map['version'] is! int ||
        map['version'] != 1 ||
        map['hour'] is! int ||
        map['minute'] is! int ||
        map['timezoneId'] is! String) {
      throw const FormatException('Invalid reminder settings.');
    }

    try {
      return ReminderSchedule(
        hour: map['hour'] as int,
        minute: map['minute'] as int,
        timezoneId: map['timezoneId'] as String,
      );
    } on ArgumentError {
      throw const FormatException('Invalid reminder settings.');
    }
  }
}
