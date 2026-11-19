import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../models/finance.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';

Future<void> showLoanSheet(BuildContext context,
    {Loan? existing, LoanDirection direction = LoanDirection.lent}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LoanSheet(existing: existing, direction: direction),
  );
}

class _LoanSheet extends StatefulWidget {
  const _LoanSheet({this.existing, required this.direction});
  final Loan? existing;
  final LoanDirection direction;

  @override
  State<_LoanSheet> createState() => _LoanSheetState();
}

class _LoanSheetState extends State<_LoanSheet> {
  late Loan l;
  late final TextEditingController _person;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    l = e == null
        ? context.read<FinanceProvider>().newLoan(widget.direction)
        : Loan(
            id: e.id,
            person: e.person,
            amount: e.amount,
            direction: e.direction,
            note: e.note,
            date: e.date,
            dueDate: e.dueDate,
            settled: e.settled,
            settledAt: e.settledAt);
    _person = TextEditingController(text: l.person);
    _amount =
        TextEditingController(text: l.amount == 0 ? '' : l.amount.toStringAsFixed(0));
    _note = TextEditingController(text: l.note);
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (_person.text.trim().isEmpty || v == null || v <= 0) {
      snack(context, 'Enter a name and a valid amount.', error: true);
      return;
    }
    l.person = _person.text.trim();
    l.amount = v;
    l.note = _note.text.trim().isEmpty ? null : _note.text.trim();
    await context.read<FinanceProvider>().saveLoan(l);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.read<SettingsProvider>().currency;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'Record a loan' : 'Edit loan',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<LoanDirection>(
            segments: const [
              ButtonSegment(
                  value: LoanDirection.lent,
                  label: Text('I lent money'),
                  icon: Icon(Icons.call_made)),
              ButtonSegment(
                  value: LoanDirection.borrowed,
                  label: Text('I borrowed'),
                  icon: Icon(Icons.call_received)),
            ],
            selected: {l.direction},
            onSelectionChanged: (s) => setState(() => l.direction = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _person,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Person / company'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                InputDecoration(labelText: 'Amount', prefixText: '$currency '),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text('Date: ${D.human(D.parse(l.date))}'),
            onTap: () async {
              final d = await pickDate(context, D.parse(l.date));
              if (d != null) setState(() => l.date = D.key(d));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat),
            title: Text(l.dueDate == null
                ? 'Due date (optional)'
                : 'Due: ${D.human(D.parse(l.dueDate!))}'),
            trailing: l.dueDate == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => l.dueDate = null)),
            onTap: () async {
              final d = await pickDate(
                  context, l.dueDate == null ? null : D.parse(l.dueDate!));
              if (d != null) setState(() => l.dueDate = D.key(d));
            },
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Save loan')),
        ],
      ),
    );
  }
}
