import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';

/// Quick dialog to set or add steps for the selected day.
Future<void> showStepsDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _StepsDialog(),
  );
}

class _StepsDialog extends StatefulWidget {
  const _StepsDialog();

  @override
  State<_StepsDialog> createState() => _StepsDialogState();
}

class _StepsDialogState extends State<_StepsDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HealthProvider>();
    final goal = context.watch<SettingsProvider>().stepGoal;
    return AlertDialog(
      title: const Text('Steps'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${Fmt.num0(h.todaySteps)} / ${Fmt.num0(goal)} steps',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [500, 1000, 2000, 5000]
                .map((n) => ActionChip(
                      label: Text('+${Fmt.num0(n)}'),
                      onPressed: () => h.addSteps(n),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Set total for the day', hintText: 'e.g. 8450'),
            onSubmitted: (_) => _set(h),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(onPressed: () => _set(h), child: const Text('Set')),
      ],
    );
  }

  Future<void> _set(HealthProvider h) async {
    final v = int.tryParse(_c.text.replaceAll(',', '').trim());
    if (v == null) return;
    await h.setSteps(v);
    if (mounted) Navigator.pop(context);
  }
}
