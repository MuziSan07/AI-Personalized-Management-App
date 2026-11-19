import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../models/learning.dart';
import '../../providers/learning_provider.dart';
import '../../widgets/common.dart';

class LearningEditScreen extends StatefulWidget {
  const LearningEditScreen({super.key, this.existing});
  final LearningGoal? existing;

  @override
  State<LearningEditScreen> createState() => _LearningEditScreenState();
}

class _LearningEditScreenState extends State<LearningEditScreen> {
  late LearningGoal g;
  late final TextEditingController _title;
  late final TextEditingController _desc;
  final _newMilestone = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = context.read<LearningProvider>();
    final e = widget.existing;
    g = e == null
        ? p.newGoal()
        : LearningGoal(
            id: e.id,
            title: e.title,
            description: e.description,
            category: e.category,
            deadline: e.deadline,
            completed: e.completed,
            createdAt: e.createdAt,
            milestones: e.milestones
                .map((m) => Milestone(
                    id: m.id,
                    goalId: m.goalId,
                    title: m.title,
                    done: m.done,
                    sortOrder: m.sortOrder))
                .toList(),
          );
    _title = TextEditingController(text: g.title);
    _desc = TextEditingController(text: g.description);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _newMilestone.dispose();
    super.dispose();
  }

  void _addMilestone() {
    final t = _newMilestone.text.trim();
    if (t.isEmpty) return;
    setState(() {
      g.milestones.add(context.read<LearningProvider>().newMilestone(g.id, t));
      _newMilestone.clear();
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      snack(context, 'Enter a goal title.', error: true);
      return;
    }
    g.title = _title.text.trim();
    g.description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    await context.read<LearningProvider>().save(g);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New learning goal' : 'Edit goal'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(
                    context, 'Delete goal?', 'Remove "${g.title}"?')) {
                  if (!context.mounted) return;
                  await context.read<LearningProvider>().delete(g.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Goal', hintText: 'e.g. Learn Flutter animations'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue:
                kLearningCategories.contains(g.category) ? g.category : 'Other',
            decoration: const InputDecoration(labelText: 'Category'),
            items: kLearningCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => g.category = v ?? 'Other'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Why / resources',
                hintText: 'Course link, book, why this matters'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text(g.deadline == null
                ? 'Deadline (optional)'
                : 'Deadline: ${D.long(D.parse(g.deadline!))}'),
            trailing: g.deadline == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => g.deadline = null)),
            onTap: () async {
              final d = await pickDate(
                  context, g.deadline == null ? null : D.parse(g.deadline!));
              if (d != null) setState(() => g.deadline = D.key(d));
            },
          ),
          const SectionHeader('Milestones'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newMilestone,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Finish chapter 3'),
                  onSubmitted: (_) => _addMilestone(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: _addMilestone, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (o, n) => setState(() {
              if (n > o) n--;
              final m = g.milestones.removeAt(o);
              g.milestones.insert(n, m);
            }),
            children: [
              for (var i = 0; i < g.milestones.length; i++)
                CheckboxListTile(
                  key: ValueKey(g.milestones[i].id),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: g.milestones[i].done,
                  onChanged: (v) =>
                      setState(() => g.milestones[i].done = v ?? false),
                  title: Text(g.milestones[i].title),
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReorderableDragStartListener(
                          index: i, child: const Icon(Icons.drag_indicator)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => g.milestones.removeAt(i)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Completed'),
            value: g.completed,
            onChanged: (v) => setState(() => g.completed = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save goal')),
        ],
      ),
    );
  }
}
