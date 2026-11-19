import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/finance.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import 'loan_sheet.dart';
import 'savings_sheet.dart';
import 'transaction_sheet.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Money'),
          actions: [
            IconButton(
              tooltip: 'Add entry',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _addMenu(context),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Transactions'),
              Tab(text: 'Loans'),
              Tab(text: 'Savings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _TransactionsTab(),
            _LoansTab(),
            _SavingsTab(),
          ],
        ),
      ),
    );
  }

  static void _addMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Color(0xFFFF7675)),
              title: const Text('Expense'),
              onTap: () {
                Navigator.pop(ctx);
                showTransactionSheet(context, type: TxType.expense);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Color(0xFF00B894)),
              title: const Text('Income'),
              subtitle: const Text('Salary, freelance payment, business'),
              onTap: () {
                Navigator.pop(ctx);
                showTransactionSheet(context, type: TxType.income);
              },
            ),
            ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: const Text('Loan'),
              subtitle: const Text('Money you lent or borrowed'),
              onTap: () {
                Navigator.pop(ctx);
                showLoanSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Savings goal'),
              onTap: () {
                Navigator.pop(ctx);
                showSavingsSheet(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Overview

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final byCat = fin.monthExpenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final daily = fin.dailyExpenses(7);
    final maxDaily = daily.fold(0.0, (m, v) => v > m ? v : m);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Row(
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => fin.setMonth(
                    DateTime(fin.month.year, fin.month.month - 1, 1))),
            Expanded(
              child: Text(D.monthName(fin.month),
                  textAlign: TextAlign.center,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => fin.setMonth(
                    DateTime(fin.month.year, fin.month.month + 1, 1))),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: StatCard(
                  label: 'Income',
                  value: Fmt.money(fin.monthIncome, cur),
                  icon: Icons.arrow_downward,
                  color: const Color(0xFF00B894)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                  label: 'Expenses',
                  value: Fmt.money(fin.monthExpense, cur),
                  icon: Icons.arrow_upward,
                  color: const Color(0xFFFF7675)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net this month', style: t.bodySmall),
                      Text(Fmt.money(fin.monthNet, cur),
                          style: t.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: fin.monthNet >= 0
                                  ? const Color(0xFF00B894)
                                  : scheme.error)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total balance', style: t.bodySmall),
                    Text(Fmt.money(fin.balance, cur),
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text('Saved ${Fmt.money(fin.totalSaved, cur)}',
                        style: t.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SectionHeader('Spending by category'),
        if (byCat.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No expenses recorded for this month yet.',
                  style: t.bodyMedium, textAlign: TextAlign.center),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 42,
                        sections: [
                          for (var i = 0; i < byCat.length; i++)
                            PieChartSectionData(
                              value: byCat[i].value,
                              color: kPalette[i % kPalette.length],
                              radius: 42,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(byCat.length, (i) {
                    final e = byCat[i];
                    final share =
                        fin.monthExpense == 0 ? 0.0 : e.value / fin.monthExpense;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: kPalette[i % kPalette.length],
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key)),
                          Text(Fmt.pct(share),
                              style: t.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(width: 10),
                          Text(Fmt.money(e.value, cur),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        const SectionHeader('Last 7 days spending'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 16, 8),
            child: SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maxDaily <= 0 ? 10 : maxDaily * 1.2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final d = D.lastNDays(7)[v.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(D.weekdayShort[d.weekday - 1],
                                style: t.labelSmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    7,
                    (i) => BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: daily[i],
                        width: 18,
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      )
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (fin.monthIncomeBySource.isNotEmpty) ...[
          const SectionHeader('Income by source'),
          Card(
            child: Column(
              children: fin.monthIncomeBySource.entries
                  .map((e) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.work_outline),
                        title: Text(e.key),
                        trailing: Text(Fmt.money(e.value, cur),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------ Transactions

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final list = fin.transactions;
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        message:
            'Log income from your job and freelance work, and every expense. Your balance updates automatically.',
        action: FilledButton.icon(
            onPressed: () => showTransactionSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add first entry')),
      );
    }
    // Group by date.
    final groups = <String, List<Transaction>>{};
    for (final tx in list) {
      groups.putIfAbsent(tx.date, () => []).add(tx);
    }
    final dates = groups.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, top: 4),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final d = dates[i];
        final txs = groups[d]!;
        final dayNet = txs.fold(
            0.0, (s, x) => s + (x.type == TxType.income ? x.amount : -x.amount));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(D.human(D.parse(d)),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Text(
                      '${dayNet >= 0 ? '+' : '-'}${Fmt.money(dayNet.abs(), cur)}',
                      style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
            ...txs.map((tx) => TransactionTile(tx: tx, currency: cur)),
          ],
        );
      },
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx, required this.currency});
  final Transaction tx;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == TxType.income;
    final color = isIncome ? const Color(0xFF00B894) : const Color(0xFFFF7675);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .15),
        child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: color, size: 20),
      ),
      title: Text(tx.note?.isNotEmpty == true ? tx.note! : tx.category),
      subtitle: Text(tx.category),
      trailing: Text(
        '${isIncome ? '+' : '-'}${Fmt.money(tx.amount, currency)}',
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
      onTap: () => showTransactionSheet(context, existing: tx),
    );
  }
}

// ------------------------------------------------------------------ Loans

class _LoansTab extends StatelessWidget {
  const _LoansTab();

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final t = Theme.of(context).textTheme;
    if (fin.loans.isEmpty) {
      return EmptyState(
        icon: Icons.handshake_outlined,
        title: 'No loans',
        message:
            'Track money you lent to friends or borrowed. Settling a loan records the payment automatically.',
        action: FilledButton.icon(
            onPressed: () => showLoanSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Record a loan')),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                  label: 'Owed to you',
                  value: Fmt.money(fin.owedToMe, cur),
                  icon: Icons.call_made,
                  color: const Color(0xFF00B894)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                  label: 'You owe',
                  value: Fmt.money(fin.iOwe, cur),
                  icon: Icons.call_received,
                  color: const Color(0xFFFF7675)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...fin.loans.map((l) {
          final lent = l.direction == LoanDirection.lent;
          final color = l.settled
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : (lent ? const Color(0xFF00B894) : const Color(0xFFFF7675));
          return Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: .15),
                child: Icon(lent ? Icons.call_made : Icons.call_received,
                    color: color, size: 20),
              ),
              title: Text(l.person,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: l.settled ? TextDecoration.lineThrough : null)),
              subtitle: Text([
                lent ? 'Lent' : 'Borrowed',
                D.human(D.parse(l.date)),
                if (l.dueDate != null && !l.settled)
                  'due ${D.human(D.parse(l.dueDate!))}',
                if (l.note != null) l.note!,
                if (l.settled) 'settled',
              ].join(' - '), style: t.bodySmall),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Fmt.money(l.amount, cur),
                      style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                  if (!l.settled)
                    TextButton(
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero),
                      onPressed: () async {
                        final ok = await confirm(
                            context,
                            'Mark as settled?',
                            lent
                                ? '${l.person} paid you back ${Fmt.money(l.amount, cur)}. This is recorded as income.'
                                : 'You paid back ${l.person} ${Fmt.money(l.amount, cur)}. This is recorded as an expense.',
                            okLabel: 'Settle');
                        if (ok && context.mounted) {
                          await context.read<FinanceProvider>().settleLoan(l);
                        }
                      },
                      child: const Text('Settle'),
                    ),
                ],
              ),
              onTap: () => showLoanSheet(context, existing: l),
              onLongPress: () async {
                if (await confirm(context, 'Delete loan?',
                    'Remove the loan with ${l.person}?')) {
                  if (context.mounted) {
                    await context.read<FinanceProvider>().deleteLoan(l.id);
                  }
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------- Savings

class _SavingsTab extends StatelessWidget {
  const _SavingsTab();

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (fin.goals.isEmpty) {
      return EmptyState(
        icon: Icons.savings_outlined,
        title: 'No savings goals',
        message:
            'Set targets like an emergency fund or a new laptop and add to them whenever you save.',
        action: FilledButton.icon(
            onPressed: () => showSavingsSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Create a goal')),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: fin.goals.map((g) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showSavingsSheet(context, existing: g),
            onLongPress: () async {
              if (await confirm(
                  context, 'Delete goal?', 'Remove "${g.title}"?')) {
                if (context.mounted) {
                  await context.read<FinanceProvider>().deleteGoal(g.id);
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProgressRing(
                        value: g.progress,
                        size: 54,
                        stroke: 6,
                        color: scheme.primary,
                        child: Text(Fmt.pct(g.progress),
                            style: t.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.title,
                                style: t.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                                '${Fmt.money(g.savedAmount, cur)} of ${Fmt.money(g.targetAmount, cur)}'
                                '${g.deadline == null ? '' : ' - by ${D.short(D.parse(g.deadline!))}'}',
                                style: t.bodySmall),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () async {
                          final v = await promptNumber(context, 'Add to savings',
                              hint: 'Amount', ok: 'Add');
                          if (v != null && v > 0 && context.mounted) {
                            await context.read<FinanceProvider>().addToGoal(g, v);
                          }
                        },
                        child: const Text('+ Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
