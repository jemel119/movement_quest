import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/reminder_schedule.dart';
import 'reminder_service.dart';

class AndroidReminderService implements ReminderService {
  static const reminderId = 1001;

  final FlutterLocalNotificationsPlugin _notifications;

  Future<void>? _initialization;

  AndroidReminderService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  Future<void> _ensureInitialized() async {
    final pending = _initialization ??= _initialize();

    try {
      await pending;
    } catch (_) {
      if (identical(_initialization, pending)) {
        _initialization = null;
      }

      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Reminders require Android.');
    }

    timezone_data.initializeTimeZones();

    final initialized = await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_workout'),
      ),
    );

    if (initialized != true) {
      throw StateError('Could not initialize reminders.');
    }
  }

  @override
  Future<ReminderSchedule?> load() async {
    await _ensureInitialized();

    final pending = await _notifications.pendingNotificationRequests();

    for (final notification in pending) {
      if (notification.id != reminderId) continue;

      final payload = notification.payload;

      if (payload == null) {
        throw const FormatException('Reminder settings are missing.');
      }

      final decoded = jsonDecode(payload);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid reminder settings.');
      }

      return ReminderSchedule.fromMap(decoded);
    }

    return null;
  }

  @override
  Future<bool> scheduleDaily({required int hour, required int minute}) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Choose a valid reminder time.');
    }

    await _ensureInitialized();

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) {
      throw StateError('Android notifications are unavailable.');
    }

    final granted = await android.requestNotificationsPermission();

    if (granted != true) return false;

    final deviceTimezone = await FlutterTimezone.getLocalTimezone();
    final location = timezone.getLocation(deviceTimezone.identifier);

    final schedule = ReminderSchedule(
      hour: hour,
      minute: minute,
      timezoneId: deviceTimezone.identifier,
    );

    final scheduledDate = nextReminderTime(
      hour: hour,
      minute: minute,
      now: timezone.TZDateTime.now(location),
    );

    await _notifications.zonedSchedule(
      id: reminderId,
      title: 'Movement Quest',
      body: 'Your workout reminder. Open the app to choose a saved plan.',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_reminders',
          'Workout reminders',
          channelDescription: 'Daily reminders selected in Settings.',
          icon: 'ic_stat_workout',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode(schedule.toMap()),
    );

    return true;
  }

  @override
  Future<void> cancel() async {
    await _ensureInitialized();
    await _notifications.cancel(id: reminderId);
  }
}

timezone.TZDateTime nextReminderTime({
  required int hour,
  required int minute,
  required timezone.TZDateTime now,
}) {
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw ArgumentError('Choose a valid reminder time.');
  }

  var next = timezone.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );

  if (!next.isAfter(now)) {
    next = timezone.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }

  return next;
}
