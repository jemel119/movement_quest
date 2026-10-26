import 'package:flutter/foundation.dart';

import '../models/reminder_schedule.dart';
import '../services/reminder_service.dart';

class ReminderController extends ChangeNotifier {
  final ReminderService _service;

  ReminderSchedule? _schedule;

  String? _error;
  String? _message;

  bool _hasLoaded = false;
  bool _isBusy = false;
  bool _disposed = false;

  ReminderController(this._service);

  ReminderSchedule? get schedule => _schedule;

  String? get error => _error;

  String? get message => _message;

  bool get hasLoaded => _hasLoaded;

  bool get isBusy => _isBusy;

  Future<bool> load() async {
    if (_disposed || _isBusy) return false;

    _isBusy = true;
    _error = null;
    _message = null;
    notifyListeners();

    try {
      final loaded = await _service.load();

      if (_disposed) return false;

      _schedule = loaded;
      _hasLoaded = true;

      return true;
    } catch (_) {
      if (!_disposed) {
        _error = 'Could not load your reminder. Try again.';
      }

      return false;
    } finally {
      _isBusy = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<bool> save({required int hour, required int minute}) async {
    if (!_canChange) return false;

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      _error = 'Choose a valid reminder time.';
      _message = null;
      notifyListeners();
      return false;
    }

    return _change(
      () => _service.scheduleDaily(hour: hour, minute: minute),
      successMessage: 'Daily reminder saved.',
      failureMessage:
          'Could not save or refresh your reminder. Reload before retrying.',
    );
  }

  Future<bool> cancel() async {
    if (!_canChange || _schedule == null) return false;

    return _change(
      () async {
        await _service.cancel();
        return true;
      },
      successMessage: 'Reminder cancelled.',
      failureMessage:
          'Could not cancel or refresh your reminder. Reload before retrying.',
    );
  }

  bool get _canChange => !_disposed && !_isBusy && _hasLoaded;

  Future<bool> _change(
    Future<bool> Function() action, {
    required String successMessage,
    required String failureMessage,
  }) async {
    if (!_canChange) return false;

    _isBusy = true;
    _error = null;
    _message = null;
    notifyListeners();

    try {
      final accepted = await action();

      if (_disposed) return false;

      if (!accepted) {
        _error =
            'Notification permission was not granted. '
            'Allow notifications in Android settings and try again.';
        return false;
      }

      final loaded = await _service.load();

      if (_disposed) return false;

      _schedule = loaded;
      _hasLoaded = true;
      _message = successMessage;

      return true;
    } catch (_) {
      if (!_disposed) {
        _hasLoaded = false;
        _error = failureMessage;
      }

      return false;
    } finally {
      _isBusy = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
