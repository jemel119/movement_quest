import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/reminder_schedule.dart';
import 'package:movement_quest/services/reminder_service.dart';
import 'package:movement_quest/widgets/reminder_panel.dart';

class ReminderPanelService implements ReminderService {
  ReminderSchedule? stored;

  bool failLoads = false;
  bool permissionGranted = true;

  int scheduleCalls = 0;
  int cancelCalls = 0;

  @override
  Future<ReminderSchedule?> load() async {
    if (failLoads) {
      throw Exception('Load failed.');
    }

    return stored;
  }

  @override
  Future<bool> scheduleDaily({required int hour, required int minute}) async {
    scheduleCalls++;

    if (!permissionGranted) return false;

    stored = ReminderSchedule(
      hour: hour,
      minute: minute,
      timezoneId: 'America/New_York',
    );

    return true;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    stored = null;
  }
}

void main() {
  Future<void> openPanel(
    WidgetTester tester,
    ReminderPanelService service,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [ReminderPanel(service: service)]),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  ReminderSchedule existingSchedule() {
    return ReminderSchedule(
      hour: 9,
      minute: 30,
      timezoneId: 'America/New_York',
    );
  }

  testWidgets('Opening the panel does not schedule or request permission', (
    tester,
  ) async {
    final service = ReminderPanelService();

    await openPanel(tester, service);

    expect(find.text('No daily reminder scheduled.'), findsOneWidget);
    expect(find.text('Schedule reminder'), findsOneWidget);
    expect(service.scheduleCalls, 0);
    expect(service.cancelCalls, 0);
  });

  testWidgets('Saving schedules the selected default time', (tester) async {
    final service = ReminderPanelService();

    await openPanel(tester, service);

    await tapControl(
      tester,
      find.widgetWithText(FilledButton, 'Schedule reminder'),
    );

    expect(service.scheduleCalls, 1);
    expect(service.stored!.hour, 18);
    expect(service.stored!.minute, 0);
    expect(find.text('Daily reminder saved.'), findsOneWidget);
    expect(find.text('Update reminder'), findsOneWidget);
    expect(find.text('Cancel reminder'), findsOneWidget);
    expect(find.text('Timezone: America/New_York'), findsOneWidget);
  });

  testWidgets('An existing reminder offers update and cancellation', (
    tester,
  ) async {
    final service = ReminderPanelService();
    service.stored = existingSchedule();

    await openPanel(tester, service);

    expect(find.text('Update reminder'), findsOneWidget);
    expect(find.text('Cancel reminder'), findsOneWidget);
    expect(find.text('Schedule reminder'), findsNothing);

    await tapControl(
      tester,
      find.widgetWithText(FilledButton, 'Update reminder'),
    );

    expect(service.scheduleCalls, 1);
    expect(service.stored!.hour, 9);
    expect(service.stored!.minute, 30);
  });

  testWidgets('Denied permission shows feedback without claiming success', (
    tester,
  ) async {
    final service = ReminderPanelService();
    service.permissionGranted = false;

    await openPanel(tester, service);

    await tapControl(
      tester,
      find.widgetWithText(FilledButton, 'Schedule reminder'),
    );

    expect(service.stored, isNull);
    expect(
      find.text(
        'Notification permission was not granted. '
        'Allow notifications in Android settings and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Daily reminder saved.'), findsNothing);
    expect(find.text('Schedule reminder'), findsOneWidget);
  });

  testWidgets('Cancellation removes the reminder from the display', (
    tester,
  ) async {
    final service = ReminderPanelService();
    service.stored = existingSchedule();

    await openPanel(tester, service);

    await tapControl(
      tester,
      find.widgetWithText(TextButton, 'Cancel reminder'),
    );

    expect(service.cancelCalls, 1);
    expect(service.stored, isNull);
    expect(find.text('Reminder cancelled.'), findsOneWidget);
    expect(find.text('No daily reminder scheduled.'), findsOneWidget);
    expect(find.text('Cancel reminder'), findsNothing);
    expect(find.text('Schedule reminder'), findsOneWidget);
  });

  testWidgets('A failed initial load can be retried', (tester) async {
    final service = ReminderPanelService();
    service.failLoads = true;

    await openPanel(tester, service);

    expect(
      find.text('Could not load your reminder. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Schedule reminder'), findsNothing);

    service.failLoads = false;

    await tapControl(
      tester,
      find.widgetWithText(FilledButton, 'Reload reminder'),
    );

    expect(find.text('No daily reminder scheduled.'), findsOneWidget);
    expect(find.text('Schedule reminder'), findsOneWidget);
    expect(find.text('Could not load your reminder. Try again.'), findsNothing);
  });

  testWidgets('Cancelling the time picker leaves the reminder unchanged', (
    tester,
  ) async {
    final service = ReminderPanelService();
    service.stored = existingSchedule();

    await openPanel(tester, service);

    await tapControl(tester, find.byType(OutlinedButton));

    expect(find.byType(TimePickerDialog), findsOneWidget);

    await tapControl(tester, find.widgetWithText(TextButton, 'Cancel'));

    expect(find.byType(TimePickerDialog), findsNothing);
    expect(service.scheduleCalls, 0);
    expect(service.stored!.hour, 9);
    expect(service.stored!.minute, 30);
  });
}
