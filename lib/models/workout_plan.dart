class WorkoutPlan {
  static const equipmentTags = ['None', 'Dumbbells', 'Band'];

  final int? id;
  final String title;
  final String equipmentTag;
  final String planNote;
  final int effortPreference;

  WorkoutPlan({
    this.id,
    required String title,
    required this.equipmentTag,
    String planNote = '',
    required this.effortPreference,
  }) : title = title.trim(),
       planNote = planNote.trim() {
    if (id != null && id! <= 0) {
      throw ArgumentError('Plan ID must be positive.');
    }
    if (this.title.isEmpty) {
      throw ArgumentError('Enter a workout title.');
    }
    if (!equipmentTags.contains(equipmentTag)) {
      throw ArgumentError('Choose a valid equipment tag.');
    }
    if (effortPreference < 1 || effortPreference > 5) {
      throw ArgumentError('Effort preference must be between 1 and 5.');
    }
  }

  WorkoutPlan copyWith({
    int? id,
    String? title,
    String? equipmentTag,
    String? planNote,
    int? effortPreference,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      equipmentTag: equipmentTag ?? this.equipmentTag,
      planNote: planNote ?? this.planNote,
      effortPreference: effortPreference ?? this.effortPreference,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'equipmentTag': equipmentTag,
      'planNote': planNote,
      'effortPreference': effortPreference,
    };
  }

  factory WorkoutPlan.fromMap(Map<String, Object?> map) {
    return WorkoutPlan(
      id: map['id'] as int?,
      title: map['title'] as String,
      equipmentTag: map['equipmentTag'] as String,
      planNote: map['planNote'] as String,
      effortPreference: map['effortPreference'] as int,
    );
  }
}
