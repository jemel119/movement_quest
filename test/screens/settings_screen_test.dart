import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/controllers/preferences_controller.dart';
import 'package:movement_quest/models/app_preferences.dart';
import 'package:movement_quest/repositories/preferences_repository.dart';
import 'package:movement_quest/screens/settings_screen.dart';
import 'package:provider/provider.dart';

class FakeSettingsRepository implements PreferencesRepository {
  AppPreferences stored;

  bool failLoads = false;
  bool failSaves = false;

  int saveCalls = 0;

  FakeSettingsRepository({AppPreferences? initial})
    : stored = initial ?? AppPreferences();

  @override
  Future<AppPreferences> load() async {
    if (failLoads) {
      throw Exception('Load failed.');
    }

    return stored;
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    saveCalls++;

    if (failSaves) {
      throw Exception('Save failed.');
    }

    stored = preferences;
  }
}

void main() {
  Future<PreferencesController> openSettings(
    WidgetTester tester,
    FakeSettingsRepository repository, {
    bool preload = true,
  }) async {
    final controller = PreferencesController(repository);

    addTearDown(controller.dispose);

    if (preload) {
      await controller.load();
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<PreferencesController>.value(
        value: controller,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );

    await tester.pumpAndSettle();

    return controller;
  }

  Future<void> selectEquipment(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Settings displays previously saved preferences', (tester) async {
    final repository = FakeSettingsRepository(
      initial: AppPreferences(equipmentPreference: 'Band', defaultEffort: 4),
    );

    await openSettings(tester, repository);

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    final slider = tester.widget<Slider>(find.byType(Slider));

    expect(find.text('Workout preferences'), findsOneWidget);
    expect(dropdown.value, 'Band');
    expect(slider.value, 4);
    expect(find.text('Default effort preference: 4 of 5'), findsOneWidget);
    expect(repository.saveCalls, 0);
  });

  testWidgets('Selecting equipment saves it without changing effort', (
    tester,
  ) async {
    final repository = FakeSettingsRepository(
      initial: AppPreferences(defaultEffort: 2),
    );

    final controller = await openSettings(tester, repository);

    await selectEquipment(tester, 'Band');

    expect(repository.saveCalls, 1);
    expect(repository.stored.equipmentPreference, 'Band');
    expect(repository.stored.defaultEffort, 2);
    expect(controller.preferences.equipmentPreference, 'Band');
    expect(find.text('Preferences saved.'), findsOneWidget);
  });

  testWidgets('No equipment and no preference save different values', (
    tester,
  ) async {
    final repository = FakeSettingsRepository();

    final controller = await openSettings(tester, repository);

    await selectEquipment(tester, 'No equipment');

    expect(repository.stored.equipmentPreference, 'None');
    expect(controller.preferences.equipmentPreference, 'None');

    await selectEquipment(tester, 'No preference');

    expect(repository.stored.equipmentPreference, isNull);
    expect(controller.preferences.equipmentPreference, isNull);
    expect(repository.saveCalls, 2);
  });

  testWidgets('Changing the effort slider saves its selected value', (
    tester,
  ) async {
    final repository = FakeSettingsRepository(
      initial: AppPreferences(equipmentPreference: 'Band', defaultEffort: 2),
    );

    final controller = await openSettings(tester, repository);

    final sliderFinder = find.byType(Slider);

    await tester.ensureVisible(sliderFinder);
    await tester.pumpAndSettle();

    final sliderRect = tester.getRect(sliderFinder);

    await tester.tapAt(Offset(sliderRect.right - 24, sliderRect.center.dy));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(sliderFinder);

    expect(repository.saveCalls, 1);
    expect(repository.stored.defaultEffort, 5);
    expect(repository.stored.equipmentPreference, 'Band');
    expect(controller.preferences.defaultEffort, 5);
    expect(slider.value, 5);
    expect(find.text('Default effort preference: 5 of 5'), findsOneWidget);
  });

  testWidgets('A failed equipment save preserves the previous preference', (
    tester,
  ) async {
    final repository = FakeSettingsRepository(
      initial: AppPreferences(equipmentPreference: 'Band', defaultEffort: 4),
    );
    repository.failSaves = true;

    final controller = await openSettings(tester, repository);

    await selectEquipment(tester, 'Dumbbells');

    expect(repository.saveCalls, 1);
    expect(repository.stored.equipmentPreference, 'Band');
    expect(controller.preferences.equipmentPreference, 'Band');
    expect(
      find.text('Could not save your preferences. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Preferences saved.'), findsNothing);

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );

    expect(dropdown.value, 'Band');

    repository.failSaves = false;

    await selectEquipment(tester, 'Dumbbells');

    expect(repository.saveCalls, 2);
    expect(repository.stored.equipmentPreference, 'Dumbbells');
    expect(controller.error, isNull);
  });

  testWidgets('A failed effort save restores the saved slider value', (
    tester,
  ) async {
    final repository = FakeSettingsRepository(
      initial: AppPreferences(defaultEffort: 2),
    );
    repository.failSaves = true;

    final controller = await openSettings(tester, repository);

    final sliderFinder = find.byType(Slider);

    await tester.ensureVisible(sliderFinder);
    await tester.pumpAndSettle();

    final sliderRect = tester.getRect(sliderFinder);

    await tester.tapAt(Offset(sliderRect.right - 24, sliderRect.center.dy));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(sliderFinder);

    expect(repository.saveCalls, 1);
    expect(repository.stored.defaultEffort, 2);
    expect(controller.preferences.defaultEffort, 2);
    expect(slider.value, 2);
    expect(find.text('Default effort preference: 2 of 5'), findsOneWidget);
    expect(
      find.text('Could not save your preferences. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('Settings loads preferences when first opened', (tester) async {
    final repository = FakeSettingsRepository(
      initial: AppPreferences(
        equipmentPreference: 'Dumbbells',
        defaultEffort: 5,
      ),
    );

    final controller = await openSettings(tester, repository, preload: false);

    expect(controller.hasLoaded, isTrue);
    expect(controller.preferences.equipmentPreference, 'Dumbbells');
    expect(find.text('Default effort preference: 5 of 5'), findsOneWidget);
  });

  testWidgets('A failed initial load offers a working retry', (tester) async {
    final repository = FakeSettingsRepository();
    repository.failLoads = true;

    final controller = await openSettings(tester, repository, preload: false);

    expect(controller.hasLoaded, isFalse);
    expect(
      find.text('Could not load your preferences. Try again.'),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);

    repository.failLoads = false;

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(controller.hasLoaded, isTrue);
    expect(controller.error, isNull);
    expect(find.text('Workout preferences'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
