import 'package:flutter/foundation.dart';

import '../models/workout_plan.dart';
import '../repositories/training_log_repository.dart';
import '../repositories/workout_repository.dart';

class WorkoutController extends ChangeNotifier {
  final WorkoutRepository _workouts;
  final TrainingLogRepository _trainingLogs;

  List<WorkoutPlan> _plans = [];
  String? _equipmentFilter;
  String? _error;
  int _completedSessions = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoaded = false;
  bool _disposed = false;

  WorkoutController(this._workouts, this._trainingLogs);

  List<WorkoutPlan> get plans {
    final filter = _equipmentFilter;

    return List<WorkoutPlan>.unmodifiable(
      filter == null
          ? _plans
          : _plans.where((plan) => plan.equipmentTag == filter),
    );
  }

  String? get equipmentFilter => _equipmentFilter;
  String? get error => _error;
  int get completedSessions => _completedSessions;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isBusy => _isLoading || _isSaving;
  bool get hasLoaded => _hasLoaded;

  void setEquipmentFilter(String? equipmentTag) {
    if (_disposed) {
      return;
    }

    if (equipmentTag != null &&
        !WorkoutPlan.equipmentTags.contains(equipmentTag)) {
      throw ArgumentError('Choose a valid equipment filter.');
    }

    if (_equipmentFilter == equipmentTag) {
      return;
    }

    _equipmentFilter = equipmentTag;
    notifyListeners();
  }

  Future<bool> load() {
    return _perform(
      action: () async {},
      failureMessage: 'Could not load your workouts. Try again.',
      loading: true,
    );
  }

  Future<WorkoutPlan?> savePlan(WorkoutPlan plan) async {
    WorkoutPlan? saved;

    await _perform(
      action: () async {
        saved = plan.id == null
            ? await _workouts.createPlan(plan)
            : await _workouts.updatePlan(plan);
      },
      failureMessage:
          'Could not save or refresh your workouts. Reload before retrying.',
    );

    return saved;
  }

  Future<bool> deletePlan(int id) {
    return _perform(
      action: () => _workouts.deletePlan(id),
      failureMessage:
          'Could not delete or refresh your workouts. Reload before retrying.',
    );
  }

  Future<void> _refresh() async {
    final updatedPlans = await _workouts.getPlans();
    final updatedCount = await _trainingLogs.countFinishedSessions();

    if (_disposed) {
      return;
    }

    _plans = updatedPlans;
    _completedSessions = updatedCount;
    _hasLoaded = true;
  }

  Future<bool> _perform({
    required Future<void> Function() action,
    required String failureMessage,
    bool loading = false,
  }) async {
    if (_disposed || isBusy) {
      return false;
    }

    _error = null;
    _isLoading = loading;
    _isSaving = !loading;
    notifyListeners();

    try {
      await action();
      await _refresh();
      return !_disposed;
    } on ArgumentError catch (error) {
      _error = error.message?.toString() ?? failureMessage;
      return false;
    } on StateError catch (error) {
      _error = error.message;
      return false;
    } catch (_) {
      _error = failureMessage;
      return false;
    } finally {
      _isLoading = false;
      _isSaving = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
