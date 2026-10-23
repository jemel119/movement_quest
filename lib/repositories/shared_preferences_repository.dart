import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_preferences.dart';
import 'preferences_repository.dart';

class SharedPreferencesRepository implements PreferencesRepository {
  static const storageKey = 'movement_quest.preferences';

  final SharedPreferences _storage;

  SharedPreferencesRepository(this._storage);

  @override
  Future<AppPreferences> load() async {
    final stored = _storage.get(storageKey);

    if (stored == null) {
      return AppPreferences();
    }

    if (stored is! String) {
      throw const FormatException('Saved preferences are invalid.');
    }

    final decoded = jsonDecode(stored);

    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        !decoded.containsKey('equipmentPreference') ||
        decoded['defaultEffort'] is! int) {
      throw const FormatException('Saved preferences are invalid.');
    }

    final equipment = decoded['equipmentPreference'];

    if (equipment != null && equipment is! String) {
      throw const FormatException('Saved equipment preference is invalid.');
    }

    try {
      return AppPreferences(
        equipmentPreference: equipment as String?,
        defaultEffort: decoded['defaultEffort'] as int,
      );
    } on ArgumentError {
      throw const FormatException('Saved preferences are invalid.');
    }
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    final saved = await _storage.setString(
      storageKey,
      jsonEncode({
        'version': 1,
        'equipmentPreference': preferences.equipmentPreference,
        'defaultEffort': preferences.defaultEffort,
      }),
    );

    if (!saved) {
      throw StateError('Could not save preferences.');
    }
  }
}
