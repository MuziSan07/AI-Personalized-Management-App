import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

/// User profile, targets and preferences, persisted with SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _p;

  String name = '';
  double weightKg = 0;
  double heightCm = 0;
  int age = 0;
  String sex = 'male';
  int calorieTarget = 2200;
  int proteinTarget = 150;
  int carbsTarget = 250;
  int fatTarget = 70;
  int stepGoal = 10000;
  String currency = 'Rs';
  bool dailySummaryEnabled = true;
  String dailySummaryTime = '08:00';
  String groqModel = '';
  bool onboarded = false;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final p = _p!;
    name = p.getString('name') ?? '';
    weightKg = p.getDouble('weightKg') ?? 0;
    heightCm = p.getDouble('heightCm') ?? 0;
    age = p.getInt('age') ?? 0;
    sex = p.getString('sex') ?? 'male';
    calorieTarget = p.getInt('calorieTarget') ?? 2200;
    proteinTarget = p.getInt('proteinTarget') ?? 150;
    carbsTarget = p.getInt('carbsTarget') ?? 250;
    fatTarget = p.getInt('fatTarget') ?? 70;
    stepGoal = p.getInt('stepGoal') ?? 10000;
    currency = p.getString('currency') ?? 'Rs';
    dailySummaryEnabled = p.getBool('dailySummaryEnabled') ?? true;
    dailySummaryTime = p.getString('dailySummaryTime') ?? '08:00';
    groqModel = p.getString('groqModel') ?? '';
    onboarded = p.getBool('onboarded') ?? false;
    notifyListeners();
  }

  Future<void> save() async {
    final p = _p ??= await SharedPreferences.getInstance();
    await p.setString('name', name);
    await p.setDouble('weightKg', weightKg);
    await p.setDouble('heightCm', heightCm);
    await p.setInt('age', age);
    await p.setString('sex', sex);
    await p.setInt('calorieTarget', calorieTarget);
    await p.setInt('proteinTarget', proteinTarget);
    await p.setInt('carbsTarget', carbsTarget);
    await p.setInt('fatTarget', fatTarget);
    await p.setInt('stepGoal', stepGoal);
    await p.setString('currency', currency);
    await p.setBool('dailySummaryEnabled', dailySummaryEnabled);
    await p.setString('dailySummaryTime', dailySummaryTime);
    await p.setString('groqModel', groqModel);
    await p.setBool('onboarded', onboarded);
    await NotificationService.instance.scheduleDailySummary(
        enabled: dailySummaryEnabled, time: dailySummaryTime);
    notifyListeners();
  }

  /// Mifflin-St Jeor estimate of maintenance calories (sedentary x1.4).
  int? get estimatedMaintenance {
    if (weightKg <= 0 || heightCm <= 0 || age <= 0) return null;
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    final bmr = sex == 'female' ? base - 161 : base + 5;
    return (bmr * 1.4).round();
  }

  String get profileSummary {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add('name: $name');
    if (age > 0) parts.add('age: $age');
    if (weightKg > 0) parts.add('weight: ${weightKg}kg');
    if (heightCm > 0) parts.add('height: ${heightCm}cm');
    parts.add('sex: $sex');
    parts.add('calorie target: $calorieTarget kcal');
    parts.add('macros target P/C/F: $proteinTarget/$carbsTarget/${fatTarget}g');
    parts.add('step goal: $stepGoal');
    parts.add('currency: $currency');
    return parts.join(', ');
  }
}
