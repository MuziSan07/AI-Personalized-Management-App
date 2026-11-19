import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../models/finance.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';

Future<void> showSavingsSheet(BuildContext context, {SavingsGoal? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SavingsSheet(existing: existing),
  );
}

class _SavingsSheet extends StatefulWidget {
  const _SavingsSheet({this.existing});
  final SavingsGoal? existing;

  @override
  State<_SavingsSheet> createState() => _SavingsSheetState();
}

class _SavingsSheetState extends State<_SavingsSheet> {
  late SavingsGoal g;
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _saved;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    g = e == null
        ? context.read<FinanceProvider>().newGoal()
        : SavingsGoal(
            id: e.id,
            title: e.title,
            targetAmount: e.targetAmount,
            savedAmount: e.savedAmount,
            deadline: e.deadline,
            createdAt: e.createdAt);
    _title = TextEditingController(text: g.title);
    _target = TextEditingController(
        text: g.targetAmount == 0 ? '' : g.targetAmount.toStringAsFixed(0));
    _saved = TextEditingController(
        text: g.savedAmount == 0 ? '' : g.savedAmount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = double.tryParse(_target.text.replaceAll(',', '').trim());
    if (_title.text.trim().isEmpty || target == null || target <= 0) {
      snack(context, 'Enter a title and a target amount.', error: true);
      return;
    }
    g.title = _title.text.trim();
    g.targetAmount = target;
    g.savedAmount =
        double.tryParse(_saved.text.replaceAll(',', '').trim()) ?? 0;
    await context.read<FinanceProvider>().saveGoal(g);
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
          Text(widget.existing == null ? 'New savings goal' : 'Edit goal',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Goal', hintText: 'e.g. Emergency fund, Laptop'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Target amount', prefixText: '$currency '),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _saved,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Already saved', prefixText: '$currency '),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text(g.deadline == null
                ? 'Target date (optional)'
                : 'By ${D.human(D.parse(g.deadline!))}'),
            trailing: g.deadline == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => g.deadline = null)),
            onTap: () async {
              final d = await pickDate(
                  context, g.deadline == null ? null : D.parse(g.deadline!));
              if (d != null) setState(() => g.deadline = D.key(d));
            },
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Save goal')),
        ],
      ),
    );
  }
}
