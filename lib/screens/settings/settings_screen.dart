import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../providers/activity_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/groq_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsProvider s;
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late final TextEditingController _cal;
  late final TextEditingController _p;
  late final TextEditingController _c;
  late final TextEditingController _f;
  late final TextEditingController _steps;
  late final TextEditingController _currency;

  @override
  void initState() {
    super.initState();
    s = context.read<SettingsProvider>();
    _name = TextEditingController(text: s.name);
    _age = TextEditingController(text: s.age == 0 ? '' : '${s.age}');
    _weight = TextEditingController(
        text: s.weightKg == 0 ? '' : s.weightKg.toStringAsFixed(1));
    _height = TextEditingController(
        text: s.heightCm == 0 ? '' : s.heightCm.toStringAsFixed(0));
    _cal = TextEditingController(text: '${s.calorieTarget}');
    _p = TextEditingController(text: '${s.proteinTarget}');
    _c = TextEditingController(text: '${s.carbsTarget}');
    _f = TextEditingController(text: '${s.fatTarget}');
    _steps = TextEditingController(text: '${s.stepGoal}');
    _currency = TextEditingController(text: s.currency);
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _weight, _height, _cal, _p, _c, _f, _steps, _currency]) {
      c.dispose();
    }
    super.dispose();
  }

  int _i(TextEditingController c, int def) =>
      int.tryParse(c.text.trim()) ?? def;
  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    s.name = _name.text.trim();
    s.age = _i(_age, 0);
    s.weightKg = _d(_weight);
    s.heightCm = _d(_height);
    s.calorieTarget = _i(_cal, 2200);
    s.proteinTarget = _i(_p, 150);
    s.carbsTarget = _i(_c, 250);
    s.fatTarget = _i(_f, 70);
    s.stepGoal = _i(_steps, 10000);
    s.currency = _currency.text.trim().isEmpty ? 'Rs' : _currency.text.trim();
    await s.save();
    if (mounted) {
      snack(context, 'Settings saved.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final t = Theme.of(context).textTheme;
    final configured = GroqService.isConfigured;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const SectionHeader('Profile'),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Your name')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                    controller: _weight,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight kg')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height cm')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'male', label: Text('Male')),
              ButtonSegment(value: 'female', label: Text('Female')),
            ],
            selected: {settings.sex},
            onSelectionChanged: (v) {
              s.sex = v.first;
              setState(() {});
            },
          ),
          const SectionHeader('Nutrition targets'),
          TextField(
            controller: _cal,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Daily calories (kcal)',
              suffixIcon: TextButton(
                onPressed: () {
                  s.weightKg = _d(_weight);
                  s.heightCm = _d(_height);
                  s.age = _i(_age, 0);
                  final est = s.estimatedMaintenance;
                  if (est == null) {
                    snack(context,
                        'Fill in age, weight and height to estimate.',
                        error: true);
                  } else {
                    _cal.text = '$est';
                    snack(context,
                        'Estimated maintenance: $est kcal (Mifflin-St Jeor, light activity).');
                  }
                },
                child: const Text('Estimate'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                    controller: _p,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Protein g')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                    controller: _c,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Carbs g')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                    controller: _f,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Fat g')),
              ),
            ],
          ),
          const SectionHeader('Activity & money'),
          TextField(
              controller: _steps,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Daily step goal')),
          const SizedBox(height: 10),
          TextField(
              controller: _currency,
              decoration: const InputDecoration(
                  labelText: 'Currency symbol', hintText: 'Rs, \$, PKR, EUR')),
          const SectionHeader('Notifications'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily summary'),
            subtitle: Text('Every day at ${D.time(settings.dailySummaryTime)}'),
            value: settings.dailySummaryEnabled,
            onChanged: (v) {
              s.dailySummaryEnabled = v;
              setState(() {});
            },
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final tm = await pickTime(context, settings.dailySummaryTime);
                  if (tm != null) {
                    s.dailySummaryTime = tm;
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.schedule),
                label: const Text('Change time'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok =
                      await NotificationService.instance.requestPermissions();
                  await NotificationService.instance.showNow(
                      'Notifications work', 'You will get reminders like this.');
                  if (context.mounted) {
                    snack(context,
                        ok ? 'Test notification sent.' : 'Permission denied.',
                        error: !ok);
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Test'),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () async {
              await context.read<ActivityProvider>().rescheduleAll();
              final pending = await NotificationService.instance.pending();
              if (context.mounted) {
                snack(context, '${pending.length} reminders scheduled.');
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Re-schedule all reminders'),
          ),
          const SectionHeader('AI (Groq Cloud)'),
          Card(
            child: ListTile(
              leading: Icon(configured ? Icons.key : Icons.key_off,
                  color: configured ? Colors.green : Theme.of(context).colorScheme.error),
              title: Text(configured ? 'API key loaded from .env' : 'No API key'),
              subtitle: Text(configured
                  ? 'Model: ${GroqService(modelOverride: settings.groqModel).model}'
                  : 'Create .env in the project root with GROQ_API_KEY=... then rebuild.'),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: settings.groqModel.isEmpty ? '' : settings.groqModel,
            decoration: const InputDecoration(labelText: 'Model'),
            items: [
              const DropdownMenuItem(
                  value: '', child: Text('Default (from .env or llama-3.3-70b)')),
              ...GroqService.availableModels
                  .map((m) => DropdownMenuItem(value: m, child: Text(m))),
              if (settings.groqModel.isNotEmpty &&
                  !GroqService.availableModels.contains(settings.groqModel))
                DropdownMenuItem(
                    value: settings.groqModel, child: Text(settings.groqModel)),
            ],
            onChanged: (v) {
              s.groqModel = v ?? '';
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save settings')),
          const SizedBox(height: 24),
          Text(
            'AI Life Manager - all your data is stored locally on this device. Only the text you send to the coach (plus a compact summary of your data) is sent to Groq.',
            style: t.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
