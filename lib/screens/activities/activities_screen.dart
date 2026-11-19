import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../models/activity.dart';
import '../../providers/activity_provider.dart';
import '../../providers/assistant_provider.dart';
import '../../widgets/common.dart';
import 'activity_edit_screen.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ActivityProvider>();
    final list = p.forSelectedDate;
    final done = list.where(p.isActivityDone).length;
    final others = p.all.where((a) => !list.contains(a)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        actions: [
          IconButton(
            tooltip: 'Generate plan with AI',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _aiPlan(context),
          ),
          IconButton(
            tooltip: 'New activity',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _edit(context, null),
          ),
        ],
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                DateStrip(selected: p.selectedDate, onSelect: p.selectDate),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(D.long(p.selectedDate),
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (list.isNotEmpty)
                        Pill('$done / ${list.length} done',
                            icon: Icons.check_circle_outline),
                    ],
                  ),
                ),
                if (list.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                          value: list.isEmpty ? 0 : done / list.length,
                          minHeight: 6),
                    ),
                  ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Nothing scheduled',
                    message:
                        'Add gym sessions, work blocks, habits or any task. Set them daily, weekly or monthly and get reminded.',
                    action: Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                            onPressed: () => _edit(context, null),
                            icon: const Icon(Icons.add),
                            label: const Text('Add activity')),
                        OutlinedButton.icon(
                            onPressed: () => _aiPlan(context),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('AI plan')),
                      ],
                    ),
                  )
                else
                  ...list.map((a) => Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        child: ActivityCard(activity: a),
                      )),
                if (others.isNotEmpty) ...[
                  const SectionHeader('Not scheduled on this day',
                      padding: EdgeInsets.fromLTRB(20, 22, 20, 6)),
                  ...others.map((a) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: a.color.withValues(alpha: .15),
                          child: Icon(a.iconData, color: a.color, size: 20),
                        ),
                        title: Text(a.title),
                        subtitle: Text(
                            '${a.scheduleLabel}${a.reminderEnabled && a.reminderTime != null ? ' - ${D.time(a.reminderTime!)}' : ''}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _edit(context, a),
                      )),
                ],
              ],
            ),
    );
  }

  static void _edit(BuildContext context, Activity? a) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ActivityEditScreen(existing: a)));
  }

  static Future<void> _aiPlan(BuildContext context) async {
    final ai = context.read<AssistantProvider>();
    if (!ai.configured) {
      snack(context,
          'Add your GROQ_API_KEY to the .env file to use AI features.',
          error: true);
      return;
    }
    final request = await promptText(
      context,
      'Describe your training goal',
      hint:
          'e.g. 4-day gym split with a shoulders day, plus calisthenics on Saturday, evenings 6pm',
      maxLines: 3,
      ok: 'Generate',
    );
    if (request == null || !context.mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    List<Activity> plan;
    try {
      plan = await ai.generateWorkoutPlan(request);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        snack(context, e.toString(), error: true);
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.pop(context);
    if (plan.isEmpty) {
      snack(context, 'The AI returned no activities. Try rephrasing.',
          error: true);
      return;
    }
    final selected = {for (final a in plan) a.id: true};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          builder: (_, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Proposed plan',
                          style: Theme.of(ctx).textTheme.titleLarge),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                          'Add ${selected.values.where((v) => v).length}'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  children: plan
                      .map((a) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  value: selected[a.id],
                                  onChanged: (v) => setState(
                                      () => selected[a.id] = v ?? false),
                                  title: Text(a.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                      '${a.scheduleLabel}${a.reminderTime != null ? ' - ${D.time(a.reminderTime!)}' : ''}'),
                                ),
                                ...a.items.map((i) => ListTile(
                                      dense: true,
                                      leading: const Icon(
                                          Icons.fitness_center,
                                          size: 18),
                                      title: Text(i.title),
                                      subtitle: i.detail == null
                                          ? null
                                          : Text(i.detail!),
                                    )),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final prov = context.read<ActivityProvider>();
    var n = 0;
    for (final a in plan.where((a) => selected[a.id] == true)) {
      await prov.save(a);
      n++;
    }
    if (context.mounted) snack(context, 'Added $n activities to your plan.');
  }
}

/// Card with activity-level checkbox and expandable exercise/sub-task list.
class ActivityCard extends StatefulWidget {
  const ActivityCard({super.key, required this.activity});
  final Activity activity;

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ActivityProvider>();
    final a = p.byId(widget.activity.id) ?? widget.activity;
    final done = p.isActivityDone(a);
    final total = a.items.length;
    final doneCount = p.doneCount(a);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: total > 0
                ? () => setState(() => _open = !_open)
                : () => p.toggleActivity(a),
            onLongPress: () => _menu(context, a),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(a.iconData, color: a.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                              color: done ? scheme.onSurfaceVariant : null,
                            )),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Pill(a.category, color: a.color),
                            if (a.reminderEnabled && a.reminderTime != null)
                              Pill(D.time(a.reminderTime!),
                                  icon: Icons.alarm,
                                  color: scheme.onSurfaceVariant),
                            if (total > 0)
                              Pill('$doneCount/$total',
                                  icon: Icons.checklist,
                                  color: done ? Colors.green : scheme.primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: done,
                    shape: const CircleBorder(),
                    onChanged: (_) => p.toggleActivity(a),
                  ),
                  if (total > 0)
                    Icon(_open ? Icons.expand_less : Icons.expand_more,
                        color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (_open && total > 0) ...[
            const Divider(height: 1),
            ...a.items.map((i) {
              final c = p.isItemDone(a.id, i.id);
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: c,
                onChanged: (_) => p.toggleItem(a, i),
                title: Text(i.title,
                    style: TextStyle(
                        decoration: c ? TextDecoration.lineThrough : null)),
                subtitle: i.detail == null ? null : Text(i.detail!),
              );
            }),
            if (a.notes != null && a.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(a.notes!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ],
      ),
    );
  }

  void _menu(BuildContext context, Activity a) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ActivityEditScreen(existing: a)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await confirm(context, 'Delete activity?',
                    'This removes "${a.title}" and its history.')) {
                  if (context.mounted) {
                    await context.read<ActivityProvider>().delete(a);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
