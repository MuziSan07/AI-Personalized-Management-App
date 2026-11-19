import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/date_utils.dart';
import '../models/finance.dart';
import '../repositories/finance_repository.dart';

class FinanceProvider extends ChangeNotifier {
  FinanceProvider(this._repo);

  final FinanceRepository _repo;
  final _uuid = const Uuid();

  List<Transaction> transactions = [];
  List<Loan> loans = [];
  List<SavingsGoal> goals = [];
  DateTime month = D.firstOfMonth(D.today());
  bool loading = true;

  Future<void> load() async {
    transactions = await _repo.transactions();
    loans = await _repo.loans();
    goals = await _repo.savingsGoals();
    loading = false;
    notifyListeners();
  }

  void setMonth(DateTime m) {
    month = D.firstOfMonth(m);
    notifyListeners();
  }

  List<Transaction> get monthTransactions {
    final k = D.monthKey(month);
    return transactions.where((t) => t.date.startsWith(k)).toList();
  }

  double _sum(Iterable<Transaction> list) =>
      list.fold(0.0, (s, t) => s + t.amount);

  double get monthIncome =>
      _sum(monthTransactions.where((t) => t.type == TxType.income));
  double get monthExpense =>
      _sum(monthTransactions.where((t) => t.type == TxType.expense));
  double get monthNet => monthIncome - monthExpense;

  double get totalIncome =>
      _sum(transactions.where((t) => t.type == TxType.income));
  double get totalExpense =>
      _sum(transactions.where((t) => t.type == TxType.expense));

  /// Cash on hand = all income - all expenses - money lent out + money borrowed
  /// (settled loans are excluded because settlement is recorded as a transaction).
  double get balance => totalIncome - totalExpense;

  double get owedToMe => loans
      .where((l) => !l.settled && l.direction == LoanDirection.lent)
      .fold(0.0, (s, l) => s + l.amount);
  double get iOwe => loans
      .where((l) => !l.settled && l.direction == LoanDirection.borrowed)
      .fold(0.0, (s, l) => s + l.amount);

  double get totalSaved => goals.fold(0.0, (s, g) => s + g.savedAmount);

  Map<String, double> get monthExpenseByCategory {
    final out = <String, double>{};
    for (final t in monthTransactions.where((t) => t.type == TxType.expense)) {
      out[t.category] = (out[t.category] ?? 0) + t.amount;
    }
    return out;
  }

  Map<String, double> get monthIncomeBySource {
    final out = <String, double>{};
    for (final t in monthTransactions.where((t) => t.type == TxType.income)) {
      out[t.category] = (out[t.category] ?? 0) + t.amount;
    }
    return out;
  }

  /// Expense per day for the last [days] days.
  List<double> dailyExpenses(int days) {
    final out = <double>[];
    for (final d in D.lastNDays(days)) {
      final k = D.key(d);
      out.add(_sum(transactions
          .where((t) => t.type == TxType.expense && t.date == k)));
    }
    return out;
  }

  Transaction newTransaction(TxType type) => Transaction(
        id: _uuid.v4(),
        type: type,
        amount: 0,
        category: type == TxType.income ? 'Professional Work' : 'Food',
        date: D.todayKey(),
        createdAt: DateTime.now(),
      );

  Future<void> saveTransaction(Transaction t) async {
    await _repo.upsertTransaction(t);
    await load();
  }

  Future<void> deleteTransaction(String id) async {
    await _repo.deleteTransaction(id);
    await load();
  }

  Loan newLoan(LoanDirection dir) => Loan(
        id: _uuid.v4(),
        person: '',
        amount: 0,
        direction: dir,
        date: D.todayKey(),
      );

  Future<void> saveLoan(Loan l) async {
    await _repo.upsertLoan(l);
    await load();
  }

  Future<void> settleLoan(Loan l, {bool recordTransaction = true}) async {
    l.settled = true;
    l.settledAt = DateTime.now();
    await _repo.upsertLoan(l);
    if (recordTransaction) {
      await _repo.upsertTransaction(Transaction(
        id: _uuid.v4(),
        type: l.direction == LoanDirection.lent ? TxType.income : TxType.expense,
        amount: l.amount,
        category: l.direction == LoanDirection.lent
            ? 'Loan Received'
            : 'Loan Repayment',
        note: l.direction == LoanDirection.lent
            ? '${l.person} paid back'
            : 'Paid back ${l.person}',
        date: D.todayKey(),
        createdAt: DateTime.now(),
      ));
    }
    await load();
  }

  Future<void> deleteLoan(String id) async {
    await _repo.deleteLoan(id);
    await load();
  }

  SavingsGoal newGoal() => SavingsGoal(
      id: _uuid.v4(), title: '', targetAmount: 0, createdAt: DateTime.now());

  Future<void> saveGoal(SavingsGoal g) async {
    await _repo.upsertSavingsGoal(g);
    await load();
  }

  Future<void> addToGoal(SavingsGoal g, double amount) async {
    g.savedAmount = (g.savedAmount + amount).clamp(0, double.infinity);
    await _repo.upsertSavingsGoal(g);
    await load();
  }

  Future<void> deleteGoal(String id) async {
    await _repo.deleteSavingsGoal(id);
    await load();
  }

  String summaryForAi(String currency) {
    final b = StringBuffer();
    b.writeln('Finance (${D.monthName(month)}): income $currency ${monthIncome.toStringAsFixed(0)}, '
        'expenses $currency ${monthExpense.toStringAsFixed(0)}, net $currency ${monthNet.toStringAsFixed(0)}. '
        'Overall balance $currency ${balance.toStringAsFixed(0)}.');
    if (monthExpenseByCategory.isNotEmpty) {
      b.writeln('Expenses by category: ${monthExpenseByCategory.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(0)}').join(', ')}');
    }
    if (monthIncomeBySource.isNotEmpty) {
      b.writeln('Income by source: ${monthIncomeBySource.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(0)}').join(', ')}');
    }
    final open = loans.where((l) => !l.settled).toList();
    if (open.isNotEmpty) {
      b.writeln('Open loans: ${open.map((l) => '${l.direction == LoanDirection.lent ? 'lent to' : 'borrowed from'} ${l.person} $currency ${l.amount.toStringAsFixed(0)}').join('; ')}');
    }
    if (goals.isNotEmpty) {
      b.writeln('Savings goals: ${goals.map((g) => '${g.title} ${g.savedAmount.toStringAsFixed(0)}/${g.targetAmount.toStringAsFixed(0)}').join('; ')}');
    }
    final recent = transactions.take(8);
    if (recent.isNotEmpty) {
      b.writeln('Recent transactions: ${recent.map((t) => '${t.date} ${t.type.name} ${t.amount.toStringAsFixed(0)} ${t.category}${t.note == null ? '' : ' (${t.note})'}').join('; ')}');
    }
    return b.toString();
  }
}
