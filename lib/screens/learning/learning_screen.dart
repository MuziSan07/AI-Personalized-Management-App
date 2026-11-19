import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/formatters.dart';
import '../../models/learning.dart';
import '../../providers/learning_provider.dart';
import '../../widgets/common.dart';
import 'learning_edit_screen.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LearningProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn'),
        actions: [
          IconButton(
            tooltip: 'New goal',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LearningEditScreen())),
          ),
        ],
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : p.goals.isEmpty
              ? EmptyState(
                  icon: Icons.school_outlined,
                  title: 'No learning goals',
                  message:
                      'Track courses, skills or certifications. Break each into milestones and tick them off.',
                  action: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const LearningEditScreen())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add a goal')),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    ...p.active.map((g) => _GoalCard(goal: g)),
                    if (p.completed.isNotEmpty) ...[
                      const SectionHeader('Completed'),
                      ...p.completed.map((g) => _GoalCard(goal: g)),
                    ],
                  ],
                ),
    );
  }
}

class _GoalCard extends StatefulWidget {
  const _GoalCard({required this.goal});
  final LearningGoal goal;

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.read<LearningProvider>();
    final g = widget.goal;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final overdue = g.deadline != null &&
        !g.completed &&
        D.parse(g.deadline!).isBefore(D.today());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _open = !_open),
            onLongPress: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LearningEditScreen(existing: g))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ProgressRing(
                    value: g.progress,
                    size: 52,
                    stroke: 6,
                    color: g.completed ? Colors.green : const Color(0xFF6C5CE7),
                    child: g.completed
                        ? const Icon(Icons.check, color: Colors.green, size: 20)
                        : Text(Fmt.pct(g.progress),
                            style: t.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.title,
                            style: t.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: g.completed
                                    ? TextDecoration.lineThrough
                                    : null)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Pill(g.category, color: const Color(0xFF6C5CE7)),
                            if (g.deadline != null)
                              Pill(
                                  'Due ${D.short(D.parse(g.deadline!))}',
                                  icon: Icons.flag_outlined,
                                  color: overdue
                                      ? scheme.error
                                      : scheme.onSurfaceVariant),
                            if (g.milestones.isNotEmpty)
                              Pill(
                                  '${g.milestones.where((m) => m.done).length}/${g.milestones.length}',
                                  icon: Icons.checklist),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => LearningEditScreen(existing: g))),
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1),
            if (g.description != null && g.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(g.description!, style: t.bodySmall),
              ),
            if (g.milestones.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                        child: Text('No milestones yet.', style: t.bodySmall)),
                    TextButton(
                      onPressed: () => p.setCompleted(g, !g.completed),
                      child: Text(g.completed
                          ? 'Mark as active'
                          : 'Mark complete'),
                    ),
                  ],
                ),
              )
            else
              ...g.milestones.map((m) => CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: m.done,
                    onChanged: (_) => p.toggleMilestone(g, m),
                    title: Text(m.title,
                        style: TextStyle(
                            decoration:
                                m.done ? TextDecoration.lineThrough : null)),
                  )),
          ],
        ],
      ),
    );
  }
}
