import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/workout_plan.dart';

void main() {
  WorkoutPlan makePlan({
    int? id,
    String title = 'Morning routine',
    String equipmentTag = 'None',
    String planNote = '',
    int effortPreference = 3,
  }) {
    return WorkoutPlan(
      id: id,
      title: title,
      equipmentTag: equipmentTag,
      planNote: planNote,
      effortPreference: effortPreference,
    );
  }

  group('WorkoutPlan', () {
    test('Trims title and notes and omits an unsaved ID', () {
      final plan = makePlan(
        title: '  Morning routine  ',
        planNote: '  My chosen exercises  ',
      );

      expect(plan.title, 'Morning routine');
      expect(plan.planNote, 'My chosen exercises');
      expect(plan.toMap().containsKey('id'), isFalse);
    });

    test('Rejects a blank title', () {
      expect(() => makePlan(title: '   '), throwsArgumentError);
    });

    test('Rejects unsupported equipment', () {
      expect(() => makePlan(equipmentTag: 'Unknown'), throwsArgumentError);
    });

    test('Accepts both effort boundaries', () {
      expect(makePlan(effortPreference: 1).effortPreference, 1);
      expect(makePlan(effortPreference: 5).effortPreference, 5);
    });

    test('Rejects effort outside the allowed range', () {
      for (final value in [0, 6]) {
        expect(() => makePlan(effortPreference: value), throwsArgumentError);
      }
    });

    test('Rejects nonpositive saved IDs', () {
      for (final value in [0, -1]) {
        expect(() => makePlan(id: value), throwsArgumentError);
      }
    });

    test('Reconstructs a saved database row', () {
      final plan = WorkoutPlan.fromMap({
        'id': 7,
        'title': 'Band routine',
        'equipmentTag': 'Band',
        'planNote': 'User-created plan',
        'effortPreference': 2,
      });

      expect(plan.id, 7);
      expect(plan.title, 'Band routine');
      expect(plan.equipmentTag, 'Band');
      expect(plan.planNote, 'User-created plan');
      expect(plan.effortPreference, 2);
      expect(plan.toMap()['id'], 7);
    });

    test('Copies changes without modifying the original', () {
      final original = makePlan(id: 7, planNote: 'Original note');
      final updated = original.copyWith(title: 'Updated routine', planNote: '');

      expect(updated.id, 7);
      expect(updated.title, 'Updated routine');
      expect(updated.planNote, '');
      expect(updated.equipmentTag, original.equipmentTag);
      expect(updated.effortPreference, original.effortPreference);
      expect(original.title, 'Morning routine');
      expect(original.planNote, 'Original note');
    });

    test('Validates changes made through copyWith', () {
      final plan = makePlan(id: 7);

      expect(() => plan.copyWith(title: ' '), throwsArgumentError);
      expect(() => plan.copyWith(effortPreference: 6), throwsArgumentError);
    });
  });
}
