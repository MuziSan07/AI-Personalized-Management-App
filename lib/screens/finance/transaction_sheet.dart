import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../models/finance.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';

/// Bottom sheet to add or edit an income/expense entry.
Future<void> showTransactionSheet(BuildContext context,
    {Transaction? existing, TxType type = TxType.expense}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TransactionSheet(existing: existing, type: type),
  );
}

class _TransactionSheet extends StatefulWidget {
  const _TransactionSheet({this.existing, required this.type});
  final Transaction? existing;
  final TxType type;

  @override
  State<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<_TransactionSheet> {
  late Transaction t;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final fin = context.read<FinanceProvider>();
    final e = widget.existing;
    t = e == null
        ? fin.newTransaction(widget.type)
        : Transaction(
            id: e.id,
            type: e.type,
            amount: e.amount,
            category: e.category,
            note: e.note,
            date: e.date,
            createdAt: e.createdAt);
    _amount = TextEditingController(
        text: t.amount == 0 ? '' : t.amount.toStringAsFixed(t.amount == t.amount.roundToDouble() ? 0 : 2));
    _note = TextEditingController(text: t.note);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<String> get _cats =>
      t.type == TxType.income ? kIncomeCategories : kExpenseCategories;

  Future<void> _save() async {
    final v = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (v == null || v <= 0) {
      snack(context, 'Enter a valid amount.', error: true);
      return;
    }
    t.amount = v;
    t.note = _note.text.trim().isEmpty ? null : _note.text.trim();
    if (!_cats.contains(t.category)) t.category = _cats.first;
    await context.read<FinanceProvider>().saveTransaction(t);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.read<SettingsProvider>().currency;
    final isIncome = t.type == TxType.income;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    widget.existing == null
                        ? (isIncome ? 'Add income' : 'Add expense')
                        : 'Edit entry',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (widget.existing != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'Delete entry?',
                        'Remove this ${t.type.name} of $currency ${t.amount}?')) {
                      if (!context.mounted) return;
                      await context
                          .read<FinanceProvider>()
                          .deleteTransaction(t.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(
                  value: TxType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.remove)),
              ButtonSegment(
                  value: TxType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.add)),
            ],
            selected: {t.type},
            onSelectionChanged: (s) => setState(() {
              t.type = s.first;
              if (!_cats.contains(t.category)) t.category = _cats.first;
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            autofocus: widget.existing == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
                prefixText: '$currency ', hintText: '0'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _cats
                .map((c) => ChoiceChip(
                      label: Text(c),
                      selected: t.category == c,
                      onSelected: (_) => setState(() => t.category = c),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: 'Note',
                hintText: isIncome
                    ? 'e.g. Client X invoice, salary'
                    : 'e.g. Lunch, gym fee'),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(D.human(D.parse(t.date))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final d = await pickDate(context, D.parse(t.date));
              if (d != null) setState(() => t.date = D.key(d));
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: _save,
              child: Text(isIncome ? 'Save income' : 'Save expense')),
        ],
      ),
    );
  }
}
