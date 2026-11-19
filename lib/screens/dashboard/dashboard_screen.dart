import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/formatters.dart';
import '../../models/finance.dart';
import '../../providers/activity_provider.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../assistant/assistant_screen.dart';
import '../finance/transaction_sheet.dart';
import '../nutrition/food_sheet.dart';
import '../nutrition/steps_dialog.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AssistantProvider>().refreshInsight();
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final acts = context.watch<ActivityProvider>();
    final fin = context.watch<FinanceProvider>();
    final health = context.watch<HealthProvider>();
    final learn = context.watch<LearningProvider>();
    final ai = context.watch<AssistantProvider>();
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final today = D.today();
    final todays = acts.forDate(today);
    final doneToday = todays.where(acts.isActivityDone).length;
    final ratio = todays.isEmpty ? 0.0 : doneToday / todays.length;
    final isTodaySelected = acts.selectedKey == D.todayKey();

    final learnAvg = learn.active.isEmpty
        ? 0.0
        : learn.active.fold(0.0, (s, g) => s + g.progress) / learn.active.length;

    final monthFin = fin.month == D.firstOfMonth(today);
    final spentThisMonth = monthFin
        ? fin.monthExpense
        : fin.transactions
            .where((x) =>
                x.type == TxType.expense &&
                x.date.startsWith(D.monthKey(today)))
            .fold(0.0, (s, x) => s + x.amount);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${_greeting()}${settings.name.isEmpty ? '' : ', ${settings.name}'}'),
            Text(D.long(today),
                style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            acts.load(),
            fin.load(),
            health.load(),
            learn.load(),
          ]);
          await ai.refreshInsight(force: true);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            _InsightCard(ai: ai),
            const SizedBox(height: 12),
            // ---- Today's plan ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ProgressRing(
                          value: ratio,
                          size: 64,
                          color: scheme.primary,
                          child: Text(Fmt.pct(ratio),
                              style: t.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Today's plan",
                                  style: t.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Text(
                                todays.isEmpty
                                    ? 'Nothing scheduled today'
                                    : '$doneToday of ${todays.length} activities done',
                                style: t.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                            onPressed: () => widget.onNavigate(1),
                            child: const Text('See all')),
                      ],
                    ),
                    if (todays.isNotEmpty) const Divider(height: 20),
                    ...todays.take(5).map((a) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          shape: const CircleBorder(),
                          checkboxShape: const CircleBorder(),
                          value: isTodaySelected ? acts.isActivityDone(a) : false,
                          onChanged: (_) async {
                            if (!isTodaySelected) await acts.selectDate(today);
                            await acts.toggleActivity(a);
                          },
                          title: Text(a.title),
                          secondary: Icon(a.iconData, color: a.color, size: 20),
                          subtitle: a.items.isEmpty
                              ? null
                              : Text('${acts.doneCount(a)}/${a.items.length} items'),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ---- Stats ----
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                StatCard(
                  label: 'Steps today',
                  value: Fmt.num0(health.todaySteps),
                  sub: 'Goal ${Fmt.num0(settings.stepGoal)} - ${Fmt.pct(health.todaySteps / settings.stepGoal)}',
                  icon: Icons.directions_walk,
                  color: const Color(0xFF00B894),
                  onTap: () => showStepsDialog(context),
                ),
                StatCard(
                  label: 'Calories today',
                  value: '${Fmt.num0(health.calories)} kcal',
                  sub: '${Fmt.num0((settings.calorieTarget - health.calories).clamp(0, 99999))} left - P${Fmt.num0(health.protein)}g',
                  icon: Icons.local_fire_department_outlined,
                  color: const Color(0xFFE17055),
                  onTap: () => widget.onNavigate(3),
                ),
                StatCard(
                  label: 'Spent this month',
                  value: Fmt.money(spentThisMonth, settings.currency),
                  sub: 'Balance ${Fmt.money(fin.balance, settings.currency)}',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF0984E3),
                  onTap: () => widget.onNavigate(2),
                ),
                StatCard(
                  label: 'Learning goals',
                  value: '${learn.active.length} active',
                  sub: learn.active.isEmpty
                      ? 'Set a goal'
                      : 'Avg progress ${Fmt.pct(learnAvg)}',
                  icon: Icons.school_outlined,
                  color: const Color(0xFF6C5CE7),
                  onTap: () => widget.onNavigate(4),
                ),
              ],
            ),
            const SectionHeader('Quick log'),
            Row(
              children: [
                _Quick(
                    icon: Icons.remove_circle_outline,
                    label: 'Expense',
                    color: const Color(0xFFFF7675),
                    onTap: () =>
                        showTransactionSheet(context, type: TxType.expense)),
                _Quick(
                    icon: Icons.add_circle_outline,
                    label: 'Income',
                    color: const Color(0xFF00B894),
                    onTap: () =>
                        showTransactionSheet(context, type: TxType.income)),
                _Quick(
                    icon: Icons.restaurant,
                    label: 'Food',
                    color: const Color(0xFFE17055),
                    onTap: () => showFoodSheet(context)),
                _Quick(
                    icon: Icons.directions_walk,
                    label: 'Steps',
                    color: const Color(0xFF0984E3),
                    onTap: () => showStepsDialog(context)),
              ],
            ),
            const SectionHeader('This month'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Bar(
                        label: 'Income',
                        value: fin.monthIncome,
                        max: [fin.monthIncome, fin.monthExpense, 1.0]
                            .reduce((a, b) => a > b ? a : b),
                        color: const Color(0xFF00B894),
                        currency: settings.currency),
                    const SizedBox(height: 10),
                    _Bar(
                        label: 'Expenses',
                        value: fin.monthExpense,
                        max: [fin.monthIncome, fin.monthExpense, 1.0]
                            .reduce((a, b) => a > b ? a : b),
                        color: const Color(0xFFFF7675),
                        currency: settings.currency),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: Text('Net',
                                style: t.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600))),
                        Text(
                          Fmt.money(fin.monthNet, settings.currency),
                          style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: fin.monthNet >= 0
                                  ? const Color(0xFF00B894)
                                  : scheme.error),
                        ),
                      ],
                    ),
                    if (fin.owedToMe > 0 || fin.iOwe > 0) ...[
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                              child: Text(
                                  'Owed to you: ${Fmt.money(fin.owedToMe, settings.currency)}',
                                  style: t.bodySmall)),
                          Text('You owe: ${Fmt.money(fin.iOwe, settings.currency)}',
                              style: t.bodySmall),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showWeeklyReview(context),
              icon: const Icon(Icons.insights_outlined),
              label: const Text('AI weekly review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.ai});
  final AssistantProvider ai;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: scheme.onPrimary, size: 18),
              const SizedBox(width: 6),
              Text('Coach insight',
                  style: t.labelLarge?.copyWith(
                      color: scheme.onPrimary, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (ai.configured)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: ai.insightLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.onPrimary))
                      : Icon(Icons.refresh, color: scheme.onPrimary, size: 18),
                  onPressed: ai.insightLoading
                      ? null
                      : () => ai.refreshInsight(force: true),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            !ai.configured
                ? 'Add your Groq API key to the .env file to unlock personalised insights, macro estimates and a coach that logs things for you.'
                : (ai.insight ??
                    (ai.insightLoading
                        ? 'Thinking about your day...'
                        : 'Tap refresh for a personalised insight.')),
            style: t.bodyMedium?.copyWith(color: scheme.onPrimary, height: 1.35),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimary.withValues(alpha: .2),
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AssistantScreen())),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Talk to coach'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(
      {required this.label,
      required this.value,
      required this.max,
      required this.color,
      required this.currency});
  final String label;
  final double value;
  final double max;
  final Color color;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: t.bodySmall)),
            Text(Fmt.money(value, currency),
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: max <= 0 ? 0 : (value / max).clamp(0, 1),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: .15),
          ),
        ),
      ],
    );
  }
}
