import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import 'food_sheet.dart';
import 'steps_dialog.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HealthProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Health'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Nutrition', icon: Icon(Icons.restaurant, size: 18)),
            Tab(text: 'Steps', icon: Icon(Icons.directions_walk, size: 18)),
          ]),
        ),
        body: Column(
          children: [
            DateStrip(selected: h.date, onSelect: h.selectDate),
            const Expanded(
              child: TabBarView(children: [_NutritionTab(), _StepsTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionTab extends StatelessWidget {
  const _NutritionTab();

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HealthProvider>();
    final s = context.watch<SettingsProvider>();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final left = s.calorieTarget - h.calories;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ProgressRing(
                  value: s.calorieTarget == 0 ? 0 : h.calories / s.calorieTarget,
                  size: 96,
                  stroke: 10,
                  color: left < 0 ? scheme.error : const Color(0xFFE17055),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Fmt.num0(h.calories),
                          style: t.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('kcal', style: t.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          left >= 0
                              ? '${Fmt.num0(left)} kcal left'
                              : '${Fmt.num0(-left)} kcal over',
                          style: t.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Target ${Fmt.num0(s.calorieTarget)} kcal',
                          style: t.bodySmall),
                      const SizedBox(height: 10),
                      _Macro('Protein', h.protein, s.proteinTarget,
                          const Color(0xFF0984E3)),
                      _Macro('Carbs', h.carbs, s.carbsTarget,
                          const Color(0xFFFDCB6E)),
                      _Macro('Fat', h.fat, s.fatTarget, const Color(0xFFFF7675)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ...kMeals.map((meal) {
          final items = h.byMeal(meal);
          final kcal = items.fold(0.0, (x, f) => x + f.calories);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                '$meal${items.isEmpty ? '' : ' - ${Fmt.num0(kcal)} kcal'}',
                action: TextButton.icon(
                  onPressed: () => showFoodSheet(context, meal: meal),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('Nothing logged', style: t.bodySmall),
                )
              else
                Card(
                  child: Column(
                    children: items
                        .map((f) => ListTile(
                              dense: true,
                              title: Text(f.name),
                              subtitle: Text(
                                  'P ${Fmt.num1(f.protein)}g - C ${Fmt.num1(f.carbs)}g - F ${Fmt.num1(f.fat)}g'),
                              trailing: Text('${Fmt.num0(f.calories)} kcal',
                                  style:
                                      const TextStyle(fontWeight: FontWeight.w700)),
                              onTap: () => showFoodSheet(context, existing: f),
                            ))
                        .toList(),
                  ),
                ),
            ],
          );
        }),
        const SectionHeader('Last 7 days'),
        _HistoryChart(
          future: h.calorieHistory(7),
          target: s.calorieTarget.toDouble(),
          color: const Color(0xFFE17055),
        ),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.value, this.target, this.color);
  final String label;
  final double value;
  final int target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: t.labelSmall)),
              Text('${Fmt.num0(value)} / ${target}g', style: t.labelSmall),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: target == 0 ? 0 : (value / target).clamp(0, 1),
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: .15),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsTab extends StatelessWidget {
  const _StepsTab();

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HealthProvider>();
    final s = context.watch<SettingsProvider>();
    final t = Theme.of(context).textTheme;
    final ratio = s.stepGoal == 0 ? 0.0 : h.todaySteps / s.stepGoal;
    final hist = h.stepsForLastDays(14);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ProgressRing(
                  value: ratio,
                  size: 160,
                  stroke: 14,
                  color: const Color(0xFF00B894),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Fmt.num0(h.todaySteps),
                          style: t.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('of ${Fmt.num0(s.stepGoal)} steps',
                          style: t.bodySmall),
                      Text(Fmt.pct(ratio),
                          style: t.labelLarge?.copyWith(
                              color: const Color(0xFF00B894),
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                        onPressed: () => showStepsDialog(context),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Log steps')),
                    OutlinedButton.icon(
                      onPressed: () => h.pedometerActive
                          ? h.stopPedometer()
                          : h.startPedometer(),
                      icon: Icon(h.pedometerActive
                          ? Icons.sensors_off
                          : Icons.sensors),
                      label: Text(h.pedometerActive
                          ? 'Stop sensor'
                          : 'Count with sensor'),
                    ),
                  ],
                ),
                if (h.pedometerActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        'Counting steps from the phone sensor while the app is open.',
                        style: t.bodySmall,
                        textAlign: TextAlign.center),
                  ),
                if (h.pedometerError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(h.pedometerError!,
                        style: t.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
        const SectionHeader('Last 14 days'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: [
                    s.stepGoal.toDouble(),
                    ...hist.map((e) => e.toDouble())
                  ].reduce((a, b) => a > b ? a : b) *
                      1.15,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: s.stepGoal.toDouble(),
                      color: const Color(0xFF00B894).withValues(alpha: .6),
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                    ),
                  ]),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final d = D.lastNDays(14)[v.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${d.day}', style: t.labelSmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    14,
                    (i) => BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: hist[i].toDouble(),
                        width: 12,
                        color: hist[i] >= s.stepGoal
                            ? const Color(0xFF00B894)
                            : const Color(0xFF00B894).withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(4),
                      )
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: Text(
                '${hist.where((v) => v >= s.stepGoal).length} of last 14 days hit the goal'),
            subtitle: Text(
                'Average ${Fmt.num0(hist.isEmpty ? 0 : hist.reduce((a, b) => a + b) / hist.length)} steps/day'),
          ),
        ),
      ],
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart(
      {required this.future, required this.target, required this.color});
  final Future<List<double>> future;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<List<double>>(
      future: future,
      builder: (_, snap) {
        final data = snap.data ?? List.filled(7, 0.0);
        final maxV = [target, ...data].reduce((a, b) => a > b ? a : b);
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
            child: SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maxV * 1.15,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                        y: target,
                        color: color.withValues(alpha: .6),
                        strokeWidth: 1.5,
                        dashArray: [6, 4]),
                  ]),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
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
                        toY: data[i],
                        width: 18,
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      )
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
