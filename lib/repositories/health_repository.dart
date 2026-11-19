import 'package:sqflite/sqflite.dart';

import '../core/app_database.dart';
import '../models/nutrition.dart';

class HealthRepository {
  Future<Database> get _db => AppDatabase.instance.db;

  // ---- Food ----
  Future<List<FoodEntry>> foodOn(String date) async {
    final db = await _db;
    final rows = await db.query('food_entries',
        where: 'date = ?', whereArgs: [date], orderBy: 'created_at ASC');
    return rows.map(FoodEntry.fromMap).toList();
  }

  Future<List<FoodEntry>> foodBetween(String from, String to) async {
    final db = await _db;
    final rows = await db.query('food_entries',
        where: 'date >= ? AND date <= ?', whereArgs: [from, to]);
    return rows.map(FoodEntry.fromMap).toList();
  }

  Future<void> upsertFood(FoodEntry e) async {
    final db = await _db;
    await db.insert('food_entries', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteFood(String id) async {
    final db = await _db;
    await db.delete('food_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Steps ----
  Future<StepEntry?> stepsOn(String date) async {
    final db = await _db;
    final rows =
        await db.query('step_entries', where: 'date = ?', whereArgs: [date]);
    return rows.isEmpty ? null : StepEntry.fromMap(rows.first);
  }

  Future<List<StepEntry>> stepsBetween(String from, String to) async {
    final db = await _db;
    final rows = await db.query('step_entries',
        where: 'date >= ? AND date <= ?',
        whereArgs: [from, to],
        orderBy: 'date ASC');
    return rows.map(StepEntry.fromMap).toList();
  }

  Future<void> upsertSteps(StepEntry e) async {
    final db = await _db;
    await db.insert('step_entries', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
