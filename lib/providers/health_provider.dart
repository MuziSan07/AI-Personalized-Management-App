import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../core/date_utils.dart';
import '../models/nutrition.dart';
import '../repositories/health_repository.dart';

/// Nutrition (calories + macros) and steps.
class HealthProvider extends ChangeNotifier {
  HealthProvider(this._repo);

  final HealthRepository _repo;
  final _uuid = const Uuid();

  DateTime date = D.today();
  List<FoodEntry> food = [];
  StepEntry? steps;
  List<StepEntry> stepHistory = [];
  bool loading = true;

  // Pedometer state
  StreamSubscription<StepCount>? _pedSub;
  int? _pedometerBaseline; // sensor count at start of day session
  int? _pedometerLast;
  bool pedometerActive = false;
  String? pedometerError;

  String get dateKey => D.key(date);

  Future<void> load() async {
    food = await _repo.foodOn(dateKey);
    steps = await _repo.stepsOn(dateKey);
    final days = D.lastNDays(14);
    stepHistory =
        await _repo.stepsBetween(D.key(days.first), D.key(days.last));
    loading = false;
    notifyListeners();
  }

  Future<void> selectDate(DateTime d) async {
    date = DateTime(d.year, d.month, d.day);
    await load();
  }

  // ---- Nutrition ----
  double get calories => food.fold(0.0, (s, f) => s + f.calories);
  double get protein => food.fold(0.0, (s, f) => s + f.protein);
  double get carbs => food.fold(0.0, (s, f) => s + f.carbs);
  double get fat => food.fold(0.0, (s, f) => s + f.fat);

  List<FoodEntry> byMeal(String meal) =>
      food.where((f) => f.meal == meal).toList();

  FoodEntry newFood({String meal = 'Lunch'}) => FoodEntry(
        id: _uuid.v4(),
        date: dateKey,
        meal: meal,
        name: '',
        calories: 0,
        createdAt: DateTime.now(),
      );

  Future<void> saveFood(FoodEntry e) async {
    await _repo.upsertFood(e);
    await load();
  }

  Future<void> deleteFood(String id) async {
    await _repo.deleteFood(id);
    await load();
  }

  Future<List<double>> calorieHistory(int days) async {
    final list = D.lastNDays(days);
    final rows = await _repo.foodBetween(D.key(list.first), D.key(list.last));
    return list.map((d) {
      final k = D.key(d);
      return rows.where((f) => f.date == k).fold(0.0, (s, f) => s + f.calories);
    }).toList();
  }

  // ---- Steps ----
  int get todaySteps => steps?.steps ?? 0;

  Future<void> setSteps(int value, {String source = 'manual'}) async {
    await _repo.upsertSteps(StepEntry(
        date: dateKey, steps: value, source: source, updatedAt: DateTime.now()));
    await load();
  }

  Future<void> addSteps(int delta) => setSteps(todaySteps + delta);

  List<int> stepsForLastDays(int days) {
    return D.lastNDays(days).map((d) {
      final k = D.key(d);
      final e = stepHistory.where((s) => s.date == k);
      return e.isEmpty ? 0 : e.first.steps;
    }).toList();
  }

  /// Starts live step counting from the device sensor. Steps counted while
  /// the app is open are added to today's total.
  Future<void> startPedometer() async {
    if (pedometerActive) return;
    pedometerError = null;
    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        pedometerError = 'Activity recognition permission denied.';
        notifyListeners();
        return;
      }
      _pedSub = Pedometer.stepCountStream.listen((event) async {
        if (_pedometerBaseline == null) {
          _pedometerBaseline = event.steps;
          _pedometerLast = event.steps;
          return;
        }
        final delta = event.steps - (_pedometerLast ?? event.steps);
        _pedometerLast = event.steps;
        if (delta > 0 && D.key(date) == D.todayKey()) {
          final current = await _repo.stepsOn(D.todayKey());
          await _repo.upsertSteps(StepEntry(
            date: D.todayKey(),
            steps: (current?.steps ?? 0) + delta,
            source: 'pedometer',
            updatedAt: DateTime.now(),
          ));
          await load();
        }
      }, onError: (e) {
        pedometerError = 'Step sensor unavailable: $e';
        pedometerActive = false;
        notifyListeners();
      });
      pedometerActive = true;
    } catch (e) {
      pedometerError = 'Step sensor unavailable: $e';
      pedometerActive = false;
    }
    notifyListeners();
  }

  Future<void> stopPedometer() async {
    await _pedSub?.cancel();
    _pedSub = null;
    _pedometerBaseline = null;
    _pedometerLast = null;
    pedometerActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pedSub?.cancel();
    super.dispose();
  }

  String summaryForAi(
      {required int calorieTarget, required int stepGoal}) {
    final b = StringBuffer();
    b.writeln('Nutrition today: ${calories.toStringAsFixed(0)}/$calorieTarget kcal, '
        'protein ${protein.toStringAsFixed(0)}g, carbs ${carbs.toStringAsFixed(0)}g, fat ${fat.toStringAsFixed(0)}g.');
    if (food.isNotEmpty) {
      b.writeln('Foods: ${food.map((f) => '${f.meal}: ${f.name} ${f.calories.toStringAsFixed(0)}kcal').join('; ')}');
    }
    b.writeln('Steps today: $todaySteps / $stepGoal. Last 7 days: ${stepsForLastDays(7).join(', ')}.');
    return b.toString();
  }
}
