import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/preferences_controller.dart';
import 'package:movement_quest/models/app_preferences.dart';
import 'package:movement_quest/repositories/preferences_repository.dart';

class FakePreferencesRepository implements PreferencesRepository {
  AppPreferences stored;

  bool failLoads = false;
  bool failSaves = false;

  int loadCalls = 0;
  int saveCalls = 0;

  Completer<void>? loadGate;
  Completer<void>? saveGate;

  FakePreferencesRepository({AppPreferences? initial})
    : stored = initial ?? AppPreferences();

  @override
  Future<AppPreferences> load() async {
    loadCalls++;

    final gate = loadGate;

    if (gate != null) {
      await gate.future;
    }

    if (failLoads) {
      throw Exception('Load failed.');
    }

    return stored;
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    saveCalls++;

    final gate = saveGate;

    if (gate != null) {
      await gate.future;
    }

    if (failSaves) {
      throw Exception('Save failed.');
    }

    stored = preferences;
  }
}

void main() {
  group('PreferencesController', () {
    test('Starts with defaults before loading', () {
      final controller = PreferencesController(FakePreferencesRepository());

      addTearDown(controller.dispose);

      expect(controller.preferences.equipmentPreference, isNull);
      expect(controller.preferences.defaultEffort, 3);
      expect(controller.hasLoaded, isFalse);
      expect(controller.isBusy, isFalse);
      expect(controller.error, isNull);
    });

    test('Loads saved preferences and notifies listeners', () async {
      final repository = FakePreferencesRepository(
        initial: AppPreferences(equipmentPreference: 'Band', defaultEffort: 4),
      );
      final controller = PreferencesController(repository);

      addTearDown(controller.dispose);

      final loadingStates = <bool>[];

      controller.addListener(() {
        loadingStates.add(controller.isLoading);
      });

      expect(await controller.load(), isTrue);
      expect(controller.preferences.equipmentPreference, 'Band');
      expect(controller.preferences.defaultEffort, 4);
      expect(controller.hasLoaded, isTrue);
      expect(controller.isBusy, isFalse);
      expect(controller.error, isNull);
      expect(loadingStates, [true, false]);
    });

    test('A failed load can be retried', () async {
      final repository = FakePreferencesRepository();
      repository.failLoads = true;

      final controller = PreferencesController(repository);

      addTearDown(controller.dispose);

      expect(await controller.load(), isFalse);
      expect(controller.hasLoaded, isFalse);
      expect(controller.error, 'Could not load your preferences. Try again.');
      expect(controller.isBusy, isFalse);

      repository.failLoads = false;

      expect(await controller.load(), isTrue);
      expect(controller.hasLoaded, isTrue);
      expect(controller.error, isNull);
    });

    test('A failed reload preserves previously loaded preferences', () async {
      final repository = FakePreferencesRepository(
        initial: AppPreferences(
          equipmentPreference: 'Dumbbells',
          defaultEffort: 5,
        ),
      );
      final controller = PreferencesController(repository);

      addTearDown(controller.dispose);

      await controller.load();

      repository.failLoads = true;

      expect(await controller.load(), isFalse);
      expect(controller.hasLoaded, isTrue);
      expect(controller.preferences.equipmentPreference, 'Dumbbells');
      expect(controller.preferences.defaultEffort, 5);
      expect(controller.error, isNotNull);
    });

    test('Saving is blocked until preferences have loaded', () async {
      final repository = FakePreferencesRepository();
      final controller = PreferencesController(repository);

      addTearDown(controller.dispose);

      expect(await controller.save(AppPreferences(defaultEffort: 5)), isFalse);
      expect(repository.saveCalls, 0);
      expect(controller.preferences.defaultEffort, 3);
    });

    test('Successful saving updates storage and controller state', () async {
      final repository = FakePreferencesRepository();
      final controller = PreferencesController(repository);

      addTearDown(controller.dispose);

      await controller.load();

      final savingStates = <bool>[];

      controller.addListener(() {
        savingStates.add(controller.isSaving);
      });

      final updated = AppPreferences(
        equipmentPreference: 'None',
        defaultEffort: 2,
      );

      expect(await controller.save(updated), isTrue);
      expect(repository.saveCalls, 1);
      expect(repository.stored, same(updated));
      expect(controller.preferences, same(updated));
      expect(controller.error, isNull);
      expect(controller.isBusy, isFalse);
      expect(savingStates, [true, false]);
    });

    test('Failed saving preserves preferences and allows retry', () async {
      final repository = FakePreferencesRepository(
        initial: AppPreferences(equipmentPreference: 'Band', defaultEffort: 2),
      );
      final controller = PreferencesController(repository);

      addTearDown(controller.dispose);

      await controller.load();

      repository.failSaves = true;

      final updated = AppPreferences(
        equipmentPreference: 'Dumbbells',
        defaultEffort: 5,
      );

      expect(await controller.save(updated), isFalse);
      expect(controller.preferences.equipmentPreference, 'Band');
      expect(controller.preferences.defaultEffort, 2);
      expect(repository.stored.equipmentPreference, 'Band');
      expect(controller.error, 'Could not save your preferences. Try again.');
      expect(controller.isBusy, isFalse);

      repository.failSaves = false;

      expect(await controller.save(updated), isTrue);
      expect(repository.saveCalls, 2);
      expect(controller.preferences, same(updated));
      expect(controller.error, isNull);
    });

    test('Pending loading blocks overlapping operations', () async {
      final repository = FakePreferencesRepository();
      final gate = Completer<void>();

      repository.loadGate = gate;

      final controller = PreferencesController(repository);

      addTearDown(controller.dispose);

      final loading = controller.load();

      expect(controller.isLoading, isTrue);
      expect(await controller.load(), isFalse);
      expect(await controller.save(AppPreferences(defaultEffort: 4)), isFalse);
      expect(repository.loadCalls, 1);
      expect(repository.saveCalls, 0);

      gate.complete();

      expect(await loading, isTrue);
      expect(controller.isBusy, isFalse);
    });

    test('Pending saving blocks overlapping operations', () async {
      final repository = FakePreferencesRepository();
      final controller = PreferencesController(repository);

      addTearDown(controller.dispose);

      await controller.load();

      final gate = Completer<void>();
      repository.saveGate = gate;

      final first = AppPreferences(defaultEffort: 4);
      final saving = controller.save(first);

      expect(controller.isSaving, isTrue);
      expect(await controller.save(AppPreferences(defaultEffort: 5)), isFalse);
      expect(await controller.load(), isFalse);
      expect(repository.saveCalls, 1);
      expect(repository.loadCalls, 1);

      gate.complete();

      expect(await saving, isTrue);
      expect(controller.preferences, same(first));
      expect(controller.isBusy, isFalse);
    });

    test('Disposal during loading prevents further notifications', () async {
      final repository = FakePreferencesRepository();
      final gate = Completer<void>();

      repository.loadGate = gate;

      final controller = PreferencesController(repository);
      var notifications = 0;

      controller.addListener(() {
        notifications++;
      });

      final loading = controller.load();

      expect(notifications, 1);

      controller.dispose();
      gate.complete();

      expect(await loading, isFalse);
      expect(notifications, 1);
      expect(controller.hasLoaded, isFalse);
      expect(await controller.load(), isFalse);
      expect(repository.loadCalls, 1);
    });

    test('Disposal during saving prevents further notifications', () async {
      final repository = FakePreferencesRepository();
      final controller = PreferencesController(repository);

      await controller.load();

      final gate = Completer<void>();
      repository.saveGate = gate;

      var notifications = 0;

      controller.addListener(() {
        notifications++;
      });

      final saving = controller.save(AppPreferences(defaultEffort: 5));

      expect(notifications, 1);

      controller.dispose();
      gate.complete();

      expect(await saving, isFalse);
      expect(notifications, 1);
      expect(controller.preferences.defaultEffort, 3);
      expect(await controller.save(AppPreferences(defaultEffort: 2)), isFalse);
      expect(repository.saveCalls, 1);
    });
  });
}
