import 'workout_plan.dart';

class AppPreferences {
  final String? equipmentPreference;
  final int defaultEffort;

  AppPreferences({this.equipmentPreference, this.defaultEffort = 3}) {
    if (equipmentPreference != null &&
        !WorkoutPlan.equipmentTags.contains(equipmentPreference)) {
      throw ArgumentError('Choose a valid equipment preference.');
    }

    if (defaultEffort < 1 || defaultEffort > 5) {
      throw ArgumentError('Default effort must be between 1 and 5.');
    }
  }

  AppPreferences withEquipmentPreference(String? value) {
    return AppPreferences(
      equipmentPreference: value,
      defaultEffort: defaultEffort,
    );
  }

  AppPreferences withDefaultEffort(int value) {
    return AppPreferences(
      equipmentPreference: equipmentPreference,
      defaultEffort: value,
    );
  }
}
