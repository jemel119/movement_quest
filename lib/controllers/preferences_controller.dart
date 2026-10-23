import 'package:flutter/foundation.dart';

import '../models/app_preferences.dart';
import '../repositories/preferences_repository.dart';

class PreferencesController extends ChangeNotifier {
  final PreferencesRepository _repository;

  AppPreferences _preferences = AppPreferences();

  bool _hasLoaded = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _disposed = false;

  String? _error;

  PreferencesController(this._repository);

  AppPreferences get preferences => _preferences;

  bool get hasLoaded => _hasLoaded;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isBusy => _isLoading || _isSaving;

  String? get error => _error;

  Future<bool> load() async {
    if (_disposed || isBusy) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final loaded = await _repository.load();

      if (_disposed) return false;

      _preferences = loaded;
      _hasLoaded = true;

      return true;
    } catch (_) {
      if (!_disposed) {
        _error = 'Could not load your preferences. Try again.';
      }

      return false;
    } finally {
      _isLoading = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<bool> save(AppPreferences preferences) async {
    if (_disposed || isBusy || !_hasLoaded) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.save(preferences);

      if (_disposed) return false;

      _preferences = preferences;

      return true;
    } catch (_) {
      if (!_disposed) {
        _error = 'Could not save your preferences. Try again.';
      }

      return false;
    } finally {
      _isSaving = false;

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
