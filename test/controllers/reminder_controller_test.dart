import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/reminder_controller.dart';
import 'package:movement_quest/models/reminder_schedule.dart';
import 'package:movement_quest/services/reminder_service.dart';

class FakeReminderService implements ReminderService {
  ReminderSchedule? stored;

  bool permissionGranted = true;
  bool failLoads = false;
  bool failWrites = false;
  bool failRefreshAfterSave = false;

  int loadCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;

  Completer<void>? scheduleGate;

  @override
  Future<ReminderSchedule?> load() async {
    loadCalls++;

    if (failLoads) {
      throw Exception('Load failed.');
    }

    return stored;
  }

  @override
  Future<bool> scheduleDaily({required int hour, required int minute}) async {
    scheduleCalls++;

    final gate = scheduleGate;

    if (gate != null) {
      await gate.future;
    }

    if (!permissionGranted) return false;

    if (failWrites) {
      throw Exception('Schedule failed.');
    }

    stored = ReminderSchedule(
      hour: hour,
      minute: minute,
      timezoneId: 'America/New_York',
    );

    if (failRefreshAfterSave) {
      failLoads = true;
    }

    return true;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;

    if (failWrites) {
      throw Exception('Cancel failed.');
    }

    stored = null;
  }
}

void main() {
  ReminderSchedule existingSchedule() {
    return ReminderSchedule(
      hour: 9,
      minute: 30,
      timezoneId: 'America/New_York',
    );
  }

  ReminderController createController(FakeReminderService service) {
    final controller = ReminderController(service);

    addTearDown(controller.dispose);

    return controller;
  }

  test('Changes are blocked before loading', () async {
    final service = FakeReminderService();
    final controller = createController(service);

    expect(await controller.save(hour: 10, minute: 0), isFalse);
    expect(await controller.cancel(), isFalse);
    expect(service.scheduleCalls, 0);
    expect(service.cancelCalls, 0);
  });

  test('Loading restores the existing reminder', () async {
    final service = FakeReminderService();
    service.stored = existingSchedule();

    final controller = createController(service);

    expect(await controller.load(), isTrue);
    expect(controller.hasLoaded, isTrue);
    expect(controller.schedule!.hour, 9);
    expect(controller.schedule!.minute, 30);
    expect(controller.isBusy, isFalse);
  });

  test('Saving schedules a reminder and updating replaces its time', () async {
    final service = FakeReminderService();
    final controller = createController(service);

    await controller.load();

    expect(await controller.save(hour: 10, minute: 15), isTrue);
    expect(controller.schedule!.hour, 10);
    expect(controller.schedule!.minute, 15);
    expect(controller.message, 'Daily reminder saved.');

    expect(await controller.save(hour: 18, minute: 45), isTrue);
    expect(service.scheduleCalls, 2);
    expect(controller.schedule!.hour, 18);
    expect(controller.schedule!.minute, 45);
    expect(controller.error, isNull);
  });

  test('Invalid times do not reach the service', () async {
    final service = FakeReminderService();
    final controller = createController(service);

    await controller.load();

    expect(await controller.save(hour: 24, minute: 0), isFalse);
    expect(await controller.save(hour: -1, minute: 0), isFalse);
    expect(await controller.save(hour: 10, minute: 60), isFalse);
    expect(await controller.save(hour: 10, minute: -1), isFalse);

    expect(service.scheduleCalls, 0);
    expect(controller.error, 'Choose a valid reminder time.');
  });

  test('Denied permission preserves the existing schedule', () async {
    final service = FakeReminderService();
    service.stored = existingSchedule();
    service.permissionGranted = false;

    final controller = createController(service);

    await controller.load();

    expect(await controller.save(hour: 18, minute: 0), isFalse);
    expect(controller.schedule!.hour, 9);
    expect(controller.schedule!.minute, 30);
    expect(controller.hasLoaded, isTrue);
    expect(
      controller.error,
      contains('Notification permission was not granted.'),
    );
    expect(controller.message, isNull);
  });

  test('Cancellation removes the saved reminder', () async {
    final service = FakeReminderService();
    service.stored = existingSchedule();

    final controller = createController(service);

    await controller.load();

    expect(await controller.cancel(), isTrue);
    expect(service.cancelCalls, 1);
    expect(service.stored, isNull);
    expect(controller.schedule, isNull);
    expect(controller.message, 'Reminder cancelled.');

    expect(await controller.cancel(), isFalse);
    expect(service.cancelCalls, 1);
  });

  test('A failed initial load can be retried', () async {
    final service = FakeReminderService();
    service.failLoads = true;

    final controller = createController(service);

    expect(await controller.load(), isFalse);
    expect(controller.hasLoaded, isFalse);
    expect(controller.error, isNotNull);

    service.failLoads = false;

    expect(await controller.load(), isTrue);
    expect(controller.hasLoaded, isTrue);
    expect(controller.error, isNull);
  });

  test('A successful schedule with failed refresh requires reload', () async {
    final service = FakeReminderService();
    final controller = createController(service);

    await controller.load();

    service.failRefreshAfterSave = true;

    expect(await controller.save(hour: 18, minute: 20), isFalse);
    expect(service.stored!.hour, 18);
    expect(controller.hasLoaded, isFalse);

    expect(await controller.save(hour: 19, minute: 0), isFalse);
    expect(service.scheduleCalls, 1);

    service.failLoads = false;
    service.failRefreshAfterSave = false;

    expect(await controller.load(), isTrue);
    expect(controller.schedule!.hour, 18);
    expect(controller.schedule!.minute, 20);
    expect(controller.error, isNull);
  });

  test('A pending save blocks overlapping operations', () async {
    final service = FakeReminderService();
    final controller = createController(service);

    await controller.load();

    final gate = Completer<void>();
    service.scheduleGate = gate;

    final saving = controller.save(hour: 18, minute: 0);

    expect(controller.isBusy, isTrue);
    expect(await controller.save(hour: 19, minute: 0), isFalse);
    expect(await controller.load(), isFalse);
    expect(await controller.cancel(), isFalse);
    expect(service.scheduleCalls, 1);

    gate.complete();

    expect(await saving, isTrue);
    expect(controller.isBusy, isFalse);
  });

  test('Disposal during saving prevents later notifications', () async {
    final service = FakeReminderService();
    final controller = ReminderController(service);

    await controller.load();

    var notifications = 0;

    controller.addListener(() {
      notifications++;
    });

    final gate = Completer<void>();
    service.scheduleGate = gate;

    final saving = controller.save(hour: 18, minute: 0);

    expect(notifications, 1);

    controller.dispose();
    gate.complete();

    expect(await saving, isFalse);
    expect(notifications, 1);
    expect(await controller.load(), isFalse);
  });
}
