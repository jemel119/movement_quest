import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/data/local_summary_file_repository.dart';
import 'package:movement_quest/models/training_summary.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory directory;
  late LocalSummaryFileRepository repository;

  TrainingSummary summary({int repetitions = 18}) {
    return TrainingSummary(
      generatedAtUtc: DateTime.utc(2026, 10, 25, 12),
      completedSessions: 1,
      unfinishedSessions: 0,
      totalSets: 2,
      totalRepetitions: repetitions,
    );
  }

  File savedFile() {
    return File(path.join(directory.path, LocalSummaryFileRepository.fileName));
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'movement_quest_summary_',
    );

    repository = LocalSummaryFileRepository(
      directoryProvider: () async => directory,
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('A missing summary returns null', () async {
    expect(await repository.read(), isNull);
  });

  test('A saved summary can be read by another repository instance', () async {
    final original = summary();

    await repository.save(original);

    final reopened = LocalSummaryFileRepository(
      directoryProvider: () async => directory,
    );

    final restored = await reopened.read();

    expect(restored, isNotNull);
    expect(restored!.toMap(), original.toMap());
    expect(await savedFile().exists(), isTrue);
  });

  test('Saving again replaces the previous snapshot', () async {
    await repository.save(summary(repetitions: 18));
    await repository.save(summary(repetitions: 30));

    final restored = await repository.read();

    expect(restored!.totalRepetitions, 30);
    expect(restored.totalSets, 2);

    final decoded =
        jsonDecode(await savedFile().readAsString()) as Map<String, dynamic>;

    expect(decoded['version'], 1);
    expect(decoded['totalRepetitions'], 30);
    expect(await File('${savedFile().path}.tmp').exists(), isFalse);
  });

  test('Malformed JSON is rejected', () async {
    await savedFile().writeAsString('{invalid');

    await expectLater(repository.read(), throwsA(isA<FormatException>()));
  });

  test('Unsupported versions are rejected', () async {
    final contents = summary().toMap();
    contents['version'] = 2;

    await savedFile().writeAsString(jsonEncode(contents));

    await expectLater(repository.read(), throwsA(isA<FormatException>()));
  });

  test('Invalid structures and totals are rejected', () async {
    final valid = summary().toMap();

    final invalidValues = [
      [],
      {'version': 1},
      {...valid, 'completedSessions': -1},
      {...valid, 'totalSets': '2'},
      {...valid, 'totalRepetitions': 1},
    ];

    for (final value in invalidValues) {
      await savedFile().writeAsString(jsonEncode(value));

      await expectLater(repository.read(), throwsA(isA<FormatException>()));
    }
  });

  test('Saving creates a missing storage directory', () async {
    final nestedDirectory = Directory(path.join(directory.path, 'summaries'));

    final nestedRepository = LocalSummaryFileRepository(
      directoryProvider: () async => nestedDirectory,
    );

    await nestedRepository.save(summary());

    expect(await nestedDirectory.exists(), isTrue);
    expect((await nestedRepository.read())!.totalRepetitions, 18);
  });
}
