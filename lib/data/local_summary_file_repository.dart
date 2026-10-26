import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/training_summary.dart';
import '../repositories/summary_file_repository.dart';

class LocalSummaryFileRepository implements SummaryFileRepository {
  static const fileName = 'training_summary.json';

  final Future<Directory> Function() _directoryProvider;

  LocalSummaryFileRepository({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  @override
  Future<void> save(TrainingSummary summary) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);

    final target = File(path.join(directory.path, fileName));
    final temporary = File('${target.path}.tmp');

    final contents = const JsonEncoder.withIndent('  ')
        .convert(summary.toMap());

    await temporary.writeAsString('$contents\n', flush: true);

    await temporary.rename(target.path);
  }

  @override
  Future<TrainingSummary?> read() async {
    final directory = await _directoryProvider();
    final file = File(path.join(directory.path, fileName));

    if (!await file.exists()) return null;

    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The summary file is invalid.');
    }

    return TrainingSummary.fromMap(decoded);
  }
}
