import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/reminder_schedule.dart';
import 'package:movement_quest/services/android_reminder_service.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  test('A future time schedules later today', () {
    final location = timezone.getLocation('America/New_York');
    final now = timezone.TZDateTime(location, 2026, 10, 25, 9);

    final next = nextReminderTime(hour: 18, minute: 30, now: now);

    expect(next.year, 2026);
    expect(next.month, 10);
    expect(next.day, 25);
    expect(next.hour, 18);
    expect(next.minute, 30);
    expect(next.isAfter(now), isTrue);
  });

  test('An equal or earlier time schedules tomorrow', () {
    final location = timezone.getLocation('America/New_York');
    final now = timezone.TZDateTime(location, 2026, 10, 25, 18, 30);

    for (final hour in [9, 18]) {
      final next = nextReminderTime(hour: hour, minute: 30, now: now);

      expect(next.day, 26);
      expect(next.hour, hour);
      expect(next.minute, 30);
      expect(next.isAfter(now), isTrue);
    }
  });

  test('Midnight correctly crosses the year boundary', () {
    final location = timezone.UTC;
    final now = timezone.TZDateTime(location, 2026, 12, 31, 23, 59);

    final next = nextReminderTime(hour: 0, minute: 0, now: now);

    expect(next.year, 2027);
    expect(next.month, 1);
    expect(next.day, 1);
    expect(next.hour, 0);
    expect(next.minute, 0);
  });

  test('Spring daylight saving preserves the selected local hour', () {
    final location = timezone.getLocation('America/New_York');
    final now = timezone.TZDateTime(location, 2026, 3, 7, 18);

    final next = nextReminderTime(hour: 18, minute: 0, now: now);

    expect(next.month, 3);
    expect(next.day, 8);
    expect(next.hour, 18);
    expect(next.difference(now), const Duration(hours: 23));
  });

  test('Autumn daylight saving preserves the selected local hour', () {
    final location = timezone.getLocation('America/New_York');
    final now = timezone.TZDateTime(location, 2026, 10, 31, 18);

    final next = nextReminderTime(hour: 18, minute: 0, now: now);

    expect(next.month, 11);
    expect(next.day, 1);
    expect(next.hour, 18);
    expect(next.difference(now), const Duration(hours: 25));
  });

  test('Invalid reminder times are rejected', () {
    final now = timezone.TZDateTime(timezone.UTC, 2026, 10, 25);

    expect(
      () => nextReminderTime(hour: 24, minute: 0, now: now),
      throwsArgumentError,
    );
    expect(
      () => nextReminderTime(hour: 10, minute: 60, now: now),
      throwsArgumentError,
    );
  });

  test('Reminder settings survive versioned serialization', () {
    final original = ReminderSchedule(
      hour: 18,
      minute: 30,
      timezoneId: 'America/New_York',
    );

    final restored = ReminderSchedule.fromMap(original.toMap());

    expect(restored.hour, 18);
    expect(restored.minute, 30);
    expect(restored.timezoneId, 'America/New_York');
  });

  test('Unsupported versions and invalid saved times are rejected', () {
    final valid = ReminderSchedule(
      hour: 18,
      minute: 30,
      timezoneId: 'America/New_York',
    ).toMap();

    for (final map in [
      {...valid, 'version': 2},
      {...valid, 'hour': 24},
      {...valid, 'minute': -1},
      {...valid, 'timezoneId': ''},
    ]) {
      expect(
        () => ReminderSchedule.fromMap(map),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
