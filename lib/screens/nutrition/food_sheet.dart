import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/nutrition.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/health_provider.dart';
import '../../widgets/common.dart';

/// Bottom sheet to log food with calories and macros. Can ask the AI to
/// estimate the numbers from a plain-text description.
Future<void> showFoodSheet(BuildContext context,
    {FoodEntry? existing, String meal = 'Lunch'}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FoodSheet(existing: existing, meal: meal),
  );
}

class _FoodSheet extends StatefulWidget {
  const _FoodSheet({this.existing, required this.meal});
  final FoodEntry? existing;
  final String meal;

  @override
  State<_FoodSheet> createState() => _FoodSheetState();
}

class _FoodSheetState extends State<_FoodSheet> {
  late FoodEntry f;
  late final TextEditingController _name;
  late final TextEditingController _cal;
  late final TextEditingController _p;
  late final TextEditingController _c;
  late final TextEditingController _fat;
  bool _estimating = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    f = e == null
        ? context.read<HealthProvider>().newFood(meal: widget.meal)
        : FoodEntry(
            id: e.id,
            date: e.date,
            meal: e.meal,
            name: e.name,
            calories: e.calories,
            protein: e.protein,
            carbs: e.carbs,
            fat: e.fat,
            createdAt: e.createdAt);
    _name = TextEditingController(text: f.name);
    _cal = TextEditingController(text: _n(f.calories));
    _p = TextEditingController(text: _n(f.protein));
    _c = TextEditingController(text: _n(f.carbs));
    _fat = TextEditingController(text: _n(f.fat));
  }

  String _n(double v) => v == 0 ? '' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  double _d(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  @override
  void dispose() {
    for (final c in [_name, _cal, _p, _c, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _estimate() async {
    final ai = context.read<AssistantProvider>();
    if (!ai.configured) {
      snack(context, 'Add GROQ_API_KEY to .env to estimate macros with AI.',
          error: true);
      return;
    }
    if (_name.text.trim().isEmpty) {
      snack(context, 'Describe the food first, e.g. "2 eggs and a paratha".',
          error: true);
      return;
    }
    setState(() => _estimating = true);
    try {
      final r = await ai.estimateMacros(_name.text.trim());
      setState(() {
        if (r['name'] != null) _name.text = r['name'].toString();
        _cal.text = _n((r['calories'] as num? ?? 0).toDouble());
        _p.text = _n((r['protein'] as num? ?? 0).toDouble());
        _c.text = _n((r['carbs'] as num? ?? 0).toDouble());
        _fat.text = _n((r['fat'] as num? ?? 0).toDouble());
        final m = r['meal']?.toString();
        if (m != null && kMeals.contains(m) && widget.existing == null) {
          f.meal = m;
        }
      });
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      snack(context, 'Enter what you ate.', error: true);
      return;
    }
    f.name = _name.text.trim();
    f.calories = _d(_cal);
    f.protein = _d(_p);
    f.carbs = _d(_c);
    f.fat = _d(_fat);
    await context.read<HealthProvider>().saveFood(f);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                child: Text(widget.existing == null ? 'Log food' : 'Edit food',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (widget.existing != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await context.read<HealthProvider>().deleteFood(f.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: kMeals
                .map((m) => ChoiceChip(
                      label: Text(m),
                      selected: f.meal == m,
                      onSelected: (_) => setState(() => f.meal = m),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What did you eat?',
              hintText: 'e.g. Chicken rice bowl, 300g',
              suffixIcon: _estimating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(
                      tooltip: 'Estimate calories & macros with AI',
                      icon: const Icon(Icons.auto_awesome),
                      onPressed: _estimate),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Calories (kcal)', prefixIcon: Icon(Icons.local_fire_department_outlined)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _p,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Protein g'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _c,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Carbs g'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fat,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fat g'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _save, child: const Text('Save food')),
        ],
      ),
    );
  }
}
