import 'package:flutter/material.dart';

import '../controllers/reminder_controller.dart';
import '../models/reminder_schedule.dart';
import '../services/android_reminder_service.dart';
import '../services/reminder_service.dart';

class ReminderPanel extends StatefulWidget {
  final ReminderService? service;

  const ReminderPanel({super.key, this.service});

  @override
  State<ReminderPanel> createState() => _ReminderPanelState();
}

class _ReminderPanelState extends State<ReminderPanel> {
  late final ReminderController _controller;

  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  ReminderSchedule? _displayedSchedule;

  bool _synced = false;
  bool _choosingTime = false;

  @override
  void initState() {
    super.initState();

    _controller = ReminderController(
      widget.service ?? AndroidReminderService(),
    );

    _controller.load();
  }

  Future<void> _chooseTime() async {
    if (_controller.isBusy || _choosingTime) return;

    setState(() => _choosingTime = true);

    try {
      final selected = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );

      if (!mounted || selected == null) return;

      setState(() => _selectedTime = selected);
    } finally {
      if (mounted) {
        setState(() => _choosingTime = false);
      }
    }
  }

  Future<void> _save() async {
    await _controller.save(
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final schedule = _controller.schedule;
        final busy = _controller.isBusy || _choosingTime;

        if (_controller.hasLoaded &&
            (!_synced || !identical(_displayedSchedule, schedule))) {
          _displayedSchedule = schedule;
          _synced = true;

          if (schedule != null) {
            _selectedTime = TimeOfDay(
              hour: schedule.hour,
              minute: schedule.minute,
            );
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set one daily workout reminder. '
              'Updating its time replaces the existing reminder.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Android may deliver the reminder later than the selected '
              'time. Notification permission is requested when saving.',
            ),
            if (_controller.isBusy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(
                semanticsLabel: 'Updating reminder',
              ),
            ],
            if (_controller.error != null) ...[
              const SizedBox(height: 16),
              Text(
                _controller.error!,
                semanticsLabel: 'Error: ${_controller.error}',
              ),
            ],
            if (_controller.message != null) ...[
              const SizedBox(height: 16),
              Text(_controller.message!),
            ],
            const SizedBox(height: 16),
            if (!_controller.hasLoaded)
              FilledButton(
                onPressed: busy ? null : _controller.load,
                child: const Text('Reload reminder'),
              )
            else ...[
              if (schedule == null)
                const Text('No daily reminder scheduled.')
              else ...[
                Text(
                  'Daily reminder: '
                  '${TimeOfDay(hour: schedule.hour, minute: schedule.minute).format(context)}',
                ),
                Text('Timezone: ${schedule.timezoneId}'),
                const SizedBox(height: 8),
                const Text(
                  'If your device timezone changes, save the reminder '
                  'again to use the new timezone.',
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy ? null : _chooseTime,
                icon: const Icon(Icons.access_time),
                label: Text('Choose time: ${_selectedTime.format(context)}'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: busy ? null : _save,
                icon: const Icon(Icons.notifications_outlined),
                label: Text(
                  schedule == null ? 'Schedule reminder' : 'Update reminder',
                ),
              ),
              if (schedule != null)
                TextButton(
                  onPressed: busy ? null : _controller.cancel,
                  child: const Text('Cancel reminder'),
                ),
              TextButton.icon(
                onPressed: busy ? null : _controller.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh reminder'),
              ),
            ],
          ],
        );
      },
    );
  }
}
