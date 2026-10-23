import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/app_preferences.dart';
import 'package:movement_quest/repositories/shared_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferencesRepository> createRepository(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);

    final storage = await SharedPreferences.getInstance();

    return SharedPreferencesRepository(storage);
  }

  group('SharedPreferencesRepository', () {
    test('Missing preferences return the defaults', () async {
      final repository = await createRepository({});

      final preferences = await repository.load();

      expect(preferences.equipmentPreference, isNull);
      expect(preferences.defaultEffort, 3);
    });

    test('Saved preferences can be loaded by another repository', () async {
      final repository = await createRepository({});

      await repository.save(
        AppPreferences(equipmentPreference: 'Band', defaultEffort: 4),
      );

      final storage = await SharedPreferences.getInstance();
      final reopened = SharedPreferencesRepository(storage);
      final preferences = await reopened.load();

      expect(preferences.equipmentPreference, 'Band');
      expect(preferences.defaultEffort, 4);
    });

    test('Clearing equipment replaces the previous preference', () async {
      final repository = await createRepository({});

      await repository.save(
        AppPreferences(equipmentPreference: 'Dumbbells', defaultEffort: 5),
      );

      await repository.save(
        AppPreferences(equipmentPreference: null, defaultEffort: 2),
      );

      final preferences = await repository.load();

      expect(preferences.equipmentPreference, isNull);
      expect(preferences.defaultEffort, 2);
    });

    test(
      'No-equipment preference remains distinct from no preference',
      () async {
        final repository = await createRepository({});

        await repository.save(AppPreferences(equipmentPreference: 'None'));

        final preferences = await repository.load();

        expect(preferences.equipmentPreference, 'None');
      },
    );

    test('Malformed JSON is rejected', () async {
      final repository = await createRepository({
        SharedPreferencesRepository.storageKey: '{invalid',
      });

      await expectLater(repository.load(), throwsA(isA<FormatException>()));
    });

    test('Unsupported stored versions are rejected', () async {
      final repository = await createRepository({
        SharedPreferencesRepository.storageKey: jsonEncode({
          'version': 2,
          'equipmentPreference': 'Band',
          'defaultEffort': 3,
        }),
      });

      await expectLater(repository.load(), throwsA(isA<FormatException>()));
    });

    test('Invalid stored values are rejected', () async {
      final invalidValues = <Object>[
        42,
        jsonEncode([]),
        jsonEncode({'version': 1, 'defaultEffort': 3}),
        jsonEncode({
          'version': 1,
          'equipmentPreference': 7,
          'defaultEffort': 3,
        }),
        jsonEncode({
          'version': 1,
          'equipmentPreference': 'Barbell',
          'defaultEffort': 3,
        }),
        jsonEncode({
          'version': 1,
          'equipmentPreference': null,
          'defaultEffort': 6,
        }),
        jsonEncode({
          'version': 1,
          'equipmentPreference': null,
          'defaultEffort': '3',
        }),
      ];

      for (final value in invalidValues) {
        final repository = await createRepository({
          SharedPreferencesRepository.storageKey: value,
        });

        await expectLater(repository.load(), throwsA(isA<FormatException>()));
      }
    });

    test('Saving preferences preserves unrelated stored values', () async {
      final repository = await createRepository({'unrelated_setting': 'keep'});

      await repository.save(AppPreferences(defaultEffort: 1));

      final storage = await SharedPreferences.getInstance();

      expect(storage.getString('unrelated_setting'), 'keep');
      expect((await repository.load()).defaultEffort, 1);
    });
  });
}
