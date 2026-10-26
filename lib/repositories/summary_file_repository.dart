import '../models/training_summary.dart';

abstract class SummaryFileRepository {
  Future<void> save(TrainingSummary summary);

  Future<TrainingSummary?> read();
}
