import 'package:sqflite/sqflite.dart';

import '../core/app_database.dart';
import '../models/activity.dart';

class ActivityRepository {
  Future<Database> get _db => AppDatabase.instance.db;

  Future<List<Activity>> getAll({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query('activities',
        where: includeArchived ? null : 'archived = 0',
        orderBy: 'created_at ASC');
    final items = await db.query('activity_items', orderBy: 'sort_order ASC');
    final byActivity = <String, List<ActivityItem>>{};
    for (final r in items) {
      final it = ActivityItem.fromMap(r);
      byActivity.putIfAbsent(it.activityId, () => []).add(it);
    }
    return rows
        .map((r) => Activity.fromMap(r, items: byActivity[r['id']] ?? []))
        .toList();
  }

  Future<void> upsert(Activity a) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('activities', a.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('activity_items',
          where: 'activity_id = ?', whereArgs: [a.id]);
      for (var i = 0; i < a.items.length; i++) {
        a.items[i].sortOrder = i;
        await txn.insert('activity_items', a.items[i].toMap());
      }
    });
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Completion>> completionsOn(String date) async {
    final db = await _db;
    final rows =
        await db.query('completions', where: 'date = ?', whereArgs: [date]);
    return rows.map(Completion.fromMap).toList();
  }

  Future<List<Completion>> completionsBetween(String from, String to) async {
    final db = await _db;
    final rows = await db.query('completions',
        where: 'date >= ? AND date <= ?', whereArgs: [from, to]);
    return rows.map(Completion.fromMap).toList();
  }

  Future<void> addCompletion(Completion c) async {
    final db = await _db;
    await db.insert('completions', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeCompletion(
      {required String activityId, String? itemId, required String date}) async {
    final db = await _db;
    if (itemId == null) {
      await db.delete('completions',
          where: 'activity_id = ? AND item_id IS NULL AND date = ?',
          whereArgs: [activityId, date]);
    } else {
      await db.delete('completions',
          where: 'activity_id = ? AND item_id = ? AND date = ?',
          whereArgs: [activityId, itemId, date]);
    }
  }

  Future<void> clearCompletions(String activityId, String date) async {
    final db = await _db;
    await db.delete('completions',
        where: 'activity_id = ? AND date = ?', whereArgs: [activityId, date]);
  }
}
