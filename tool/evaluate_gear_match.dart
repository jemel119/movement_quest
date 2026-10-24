import 'dart:convert';
import 'dart:io';

import 'package:movement_quest/models/training_log.dart';
import 'package:movement_quest/models/workout_plan.dart';
import 'package:movement_quest/services/gear_match_service.dart';

Map<String, Object?> evaluateMethod(
  GearMatchResult? Function() action,
  int referencePlanId,
) {
  try {
    final result = action();

    return {
      'planId': result?.plan.id,
      'score': result?.score,
      'matchesReference': result?.plan.id == referencePlanId,
      'error': null,
    };
  } catch (error) {
    return {
      'planId': null,
      'score': null,
      'matchesReference': false,
      'error': error.toString(),
    };
  }
}

String gitValue(List<String> arguments) {
  final result = Process.runSync('git', arguments);

  if (result.exitCode != 0) {
    throw StateError('Could not read Git evaluation metadata.');
  }

  final value = result.stdout.toString().trim();

  if (value.isEmpty) {
    throw StateError('Git evaluation metadata is missing.');
  }

  return value;
}

void main() {
  const inputPath = 'evaluation/gear_match_held_out.json';
  const outputPath = 'evaluation/gear_match_results.json';

  final source =
      jsonDecode(File(inputPath).readAsStringSync()) as Map<String, dynamic>;

  if (source['version'] != 1) {
    throw const FormatException('Unsupported evaluation version.');
  }

  final cases = source['cases'] as List<dynamic>;

  if (cases.length < 5) {
    throw const FormatException('At least five held-out cases are required.');
  }

  final service = GearMatchService();
  final results = <Map<String, Object?>>[];
  final caseIds = <String>{};

  var helperMatches = 0;
  var baselineMatches = 0;
  var helperErrors = 0;
  var baselineErrors = 0;

  for (final value in cases) {
    final testCase = value as Map<String, dynamic>;
    final caseId = testCase['id'] as String;

    if (!caseIds.add(caseId)) {
      throw FormatException('Duplicate case ID: $caseId');
    }

    final plans = (testCase['plans'] as List<dynamic>).map((value) {
      final row = value as Map<String, dynamic>;
      final id = row['id'] as int;

      return WorkoutPlan(
        id: id,
        title: 'Plan $id',
        equipmentTag: row['equipmentTag'] as String,
        effortPreference: 3,
      );
    }).toList();

    final logRows = testCase['logs'] as List<dynamic>;

    final logs = List<TrainingLog>.generate(logRows.length, (index) {
      final row = logRows[index] as Map<String, dynamic>;
      final key = row['sessionKey'] as String;

      return TrainingLog(
        id: index + 1,
        workoutId: row['workoutId'] as int,
        sessionKey: key,
        sessionLabel: key,
        exerciseLabel: 'Evaluation set ${index + 1}',
        repetitions: 1,
        loggedAt: DateTime.parse(row['loggedAt'] as String),
        sessionFinished: row['sessionFinished'] as bool,
      );
    });

    final referencePlanId = testCase['referencePlanId'] as int;
    final preference = testCase['equipmentPreference'] as String?;

    if (!plans.any((plan) => plan.id == referencePlanId)) {
      throw FormatException(
        '$caseId references a plan that is not in its catalog.',
      );
    }

    final helper = evaluateMethod(
      () => service.recommend(
        plans: plans,
        logs: logs,
        equipmentPreference: preference,
      ),
      referencePlanId,
    );

    final baseline = evaluateMethod(
      () => service.baseline(plans: plans, equipmentPreference: preference),
      referencePlanId,
    );

    if (helper['matchesReference'] == true) helperMatches++;
    if (baseline['matchesReference'] == true) baselineMatches++;
    if (helper['error'] != null) helperErrors++;
    if (baseline['error'] != null) baselineErrors++;

    results.add({
      'id': caseId,
      'description': testCase['description'],
      'referencePlanId': referencePlanId,
      'helper': helper,
      'baseline': baseline,
    });

    stdout.writeln(
      '$caseId: reference=$referencePlanId, '
      'helper=${helper['planId']}, '
      'baseline=${baseline['planId']}',
    );

    if (helper['error'] != null) {
      stdout.writeln('  Helper error: ${helper['error']}');
    }

    if (baseline['error'] != null) {
      stdout.writeln('  Baseline error: ${baseline['error']}');
    }
  }

  final report = {
    'version': 1,
    'evaluatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'sourceRevision': gitValue(['rev-parse', 'HEAD']),
    'casesCommit': gitValue(['log', '-1', '--format=%H', '--', inputPath]),
    'inputFile': inputPath,
    'referenceBasis': source['referenceBasis'],
    'sampleSize': cases.length,
    'helper': {
      'matches': helperMatches,
      'mismatches': cases.length - helperMatches,
      'runtimeErrors': helperErrors,
    },
    'baseline': {
      'matches': baselineMatches,
      'mismatches': cases.length - baselineMatches,
      'runtimeErrors': baselineErrors,
    },
    'cases': results,
  };

  File(outputPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );

  stdout.writeln();
  stdout.writeln(
    'Gear Match: $helperMatches/${cases.length} reference matches; '
    '$helperErrors runtime errors.',
  );
  stdout.writeln(
    'Baseline: $baselineMatches/${cases.length} reference matches; '
    '$baselineErrors runtime errors.',
  );
  stdout.writeln('Results saved to $outputPath');
}
