import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/app_preferences.dart';
import 'package:movement_quest/models/workout_plan.dart';

void main() {
  group('AppPreferences', () {
    test('Defaults to no equipment preference and effort three', () {
      final preferences = AppPreferences();

      expect(preferences.equipmentPreference, isNull);
      expect(preferences.defaultEffort, 3);
    });

    test('Accepts every supported equipment preference', () {
      for (final tag in WorkoutPlan.equipmentTags) {
        final preferences = AppPreferences(equipmentPreference: tag);

        expect(preferences.equipmentPreference, tag);
      }
    });

    test('Rejects unsupported equipment preferences', () {
      expect(
        () => AppPreferences(equipmentPreference: 'Barbell'),
        throwsArgumentError,
      );
    });

    test('Accepts both effort boundaries', () {
      expect(AppPreferences(defaultEffort: 1).defaultEffort, 1);
      expect(AppPreferences(defaultEffort: 5).defaultEffort, 5);
    });

    test('Rejects effort outside the supported range', () {
      for (final value in [0, 6]) {
        expect(() => AppPreferences(defaultEffort: value), throwsArgumentError);
      }
    });

    test('Changing equipment preserves the default effort', () {
      final original = AppPreferences(
        equipmentPreference: 'Band',
        defaultEffort: 4,
      );

      final updated = original.withEquipmentPreference('Dumbbells');

      expect(updated.equipmentPreference, 'Dumbbells');
      expect(updated.defaultEffort, 4);
      expect(original.equipmentPreference, 'Band');
    });

    test('Equipment preference can be cleared', () {
      final original = AppPreferences(
        equipmentPreference: 'None',
        defaultEffort: 2,
      );

      final updated = original.withEquipmentPreference(null);

      expect(updated.equipmentPreference, isNull);
      expect(updated.defaultEffort, 2);
      expect(original.equipmentPreference, 'None');
    });

    test('Changing effort preserves the equipment preference', () {
      final original = AppPreferences(
        equipmentPreference: 'Band',
        defaultEffort: 2,
      );

      final updated = original.withDefaultEffort(5);

      expect(updated.defaultEffort, 5);
      expect(updated.equipmentPreference, 'Band');
      expect(original.defaultEffort, 2);
    });

    test('Preference changes still enforce validation', () {
      final preferences = AppPreferences();

      expect(
        () => preferences.withEquipmentPreference('Invalid'),
        throwsArgumentError,
      );
      expect(() => preferences.withDefaultEffort(6), throwsArgumentError);
    });
  });
}
