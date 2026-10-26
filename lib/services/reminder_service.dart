import '../models/reminder_schedule.dart';

abstract class ReminderService {
  Future<ReminderSchedule?> load();

  Future<bool> scheduleDaily({required int hour, required int minute});

  Future<void> cancel();
}
