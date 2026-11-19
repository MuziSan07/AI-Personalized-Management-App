import 'package:sqflite/sqflite.dart' hide Transaction;

import '../core/app_database.dart';
import '../models/finance.dart';

class FinanceRepository {
  Future<Database> get _db => AppDatabase.instance.db;

  // ---- Transactions ----
  Future<List<Transaction>> transactions({String? from, String? to}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(to);
    }
    final rows = await db.query('transactions',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'date DESC, created_at DESC');
    return rows.map(Transaction.fromMap).toList();
  }

  Future<void> upsertTransaction(Transaction t) async {
    final db = await _db;
    await db.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _db;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns {'income': x, 'expense': y} for all time.
  Future<Map<String, double>> totals() async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT type, SUM(amount) AS total FROM transactions GROUP BY type');
    final out = {'income': 0.0, 'expense': 0.0};
    for (final r in rows) {
      out[r['type'] as String] = (r['total'] as num?)?.toDouble() ?? 0;
    }
    return out;
  }

  // ---- Loans ----
  Future<List<Loan>> loans() async {
    final db = await _db;
    final rows = await db.query('loans', orderBy: 'settled ASC, date DESC');
    return rows.map(Loan.fromMap).toList();
  }

  Future<void> upsertLoan(Loan l) async {
    final db = await _db;
    await db.insert('loans', l.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLoan(String id) async {
    final db = await _db;
    await db.delete('loans', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Savings goals ----
  Future<List<SavingsGoal>> savingsGoals() async {
    final db = await _db;
    final rows = await db.query('savings_goals', orderBy: 'created_at ASC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<void> upsertSavingsGoal(SavingsGoal g) async {
    final db = await _db;
    await db.insert('savings_goals', g.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSavingsGoal(String id) async {
    final db = await _db;
    await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }
}
