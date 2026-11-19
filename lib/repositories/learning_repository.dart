import 'package:sqflite/sqflite.dart';

import '../core/app_database.dart';
import '../models/learning.dart';

class LearningRepository {
  Future<Database> get _db => AppDatabase.instance.db;

  Future<List<LearningGoal>> getAll() async {
    final db = await _db;
    final rows =
        await db.query('learning_goals', orderBy: 'completed ASC, created_at ASC');
    final ms = await db.query('milestones', orderBy: 'sort_order ASC');
    final byGoal = <String, List<Milestone>>{};
    for (final r in ms) {
      final m = Milestone.fromMap(r);
      byGoal.putIfAbsent(m.goalId, () => []).add(m);
    }
    return rows
        .map((r) => LearningGoal.fromMap(r, milestones: byGoal[r['id']] ?? []))
        .toList();
  }

  Future<void> upsert(LearningGoal g) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('learning_goals', g.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('milestones', where: 'goal_id = ?', whereArgs: [g.id]);
      for (var i = 0; i < g.milestones.length; i++) {
        g.milestones[i].sortOrder = i;
        await txn.insert('milestones', g.milestones[i].toMap());
      }
    });
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('learning_goals', where: 'id = ?', whereArgs: [id]);
  }
}
