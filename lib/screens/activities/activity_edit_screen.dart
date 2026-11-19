import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../providers/activity_provider.dart';
import '../../widgets/common.dart';

class ActivityEditScreen extends StatefulWidget {
  const ActivityEditScreen({super.key, this.existing});
  final Activity? existing;

  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  late Activity a;
  late final TextEditingController _title;
  late final TextEditingController _notes;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final p = context.read<ActivityProvider>();
    final e = widget.existing;
    a = e == null
        ? (p.newActivity()
          ..recurrence = Recurrence.weekly
          ..weekdays = [DateTime.now().weekday])
        : Activity(
            id: e.id,
            title: e.title,
            category: e.category,
            notes: e.notes,
            recurrence: e.recurrence,
            weekdays: [...e.weekdays],
            dayOfMonth: e.dayOfMonth,
            startDate: e.startDate,
            reminderTime: e.reminderTime,
            reminderEnabled: e.reminderEnabled,
            colorValue: e.colorValue,
            icon: e.icon,
            archived: e.archived,
            createdAt: e.createdAt,
            items: e.items
                .map((i) => ActivityItem(
                    id: i.id,
                    activityId: i.activityId,
                    title: i.title,
                    detail: i.detail,
                    sortOrder: i.sortOrder))
                .toList(),
          );
    _title = TextEditingController(text: a.title);
    _notes = TextEditingController(text: a.notes);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (a.recurrence == Recurrence.weekly && a.weekdays.isEmpty) {
      snack(context, 'Pick at least one weekday.', error: true);
      return;
    }
    if (a.recurrence == Recurrence.once && a.startDate == null) {
      snack(context, 'Pick a date for this one-time activity.', error: true);
      return;
    }
    if (a.reminderEnabled && a.reminderTime == null) a.reminderTime = '08:00';
    a.title = _title.text.trim();
    a.notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    await context.read<ActivityProvider>().save(a);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addItem() async {
    final r = await _itemDialog(context);
    if (r == null) return;
    setState(() => a.items.add(context
        .read<ActivityProvider>()
        .newItem(a.id, r.$1, detail: r.$2)));
  }

  Future<void> _editItem(ActivityItem i) async {
    final r = await _itemDialog(context, title: i.title, detail: i.detail);
    if (r == null) return;
    setState(() {
      i.title = r.$1;
      i.detail = r.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isGym = a.category == 'Gym' || a.category == 'Calisthenics';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New activity' : 'Edit activity'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, 'Delete activity?',
                    'This removes "${a.title}" and its history.')) {
                  if (!context.mounted) return;
                  await context.read<ActivityProvider>().delete(a);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Title', hintText: 'e.g. Shoulders day'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: kActivityCategories.contains(a.category)
                  ? a.category
                  : 'Other',
              decoration: const InputDecoration(labelText: 'Category'),
              items: kActivityCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => a.category = v ?? 'Other'),
            ),
            const SectionHeader('Look'),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: kActivityIcons.entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Icon(e.value, size: 20),
                            selected: a.icon == e.key,
                            onSelected: (_) => setState(() => a.icon = e.key),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kPalette
                  .map((c) => GestureDetector(
                        onTap: () =>
                            setState(() => a.colorValue = c.toARGB32()),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                                width: 3,
                                color: a.colorValue == c.toARGB32()
                                    ? scheme.onSurface
                                    : Colors.transparent),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SectionHeader('Schedule'),
            SegmentedButton<Recurrence>(
              segments: Recurrence.values
                  .map((r) => ButtonSegment(value: r, label: Text(r.label)))
                  .toList(),
              selected: {a.recurrence},
              onSelectionChanged: (s) =>
                  setState(() => a.recurrence = s.first),
            ),
            const SizedBox(height: 12),
            if (a.recurrence == Recurrence.weekly)
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) {
                  final wd = i + 1;
                  final sel = a.weekdays.contains(wd);
                  return FilterChip(
                    label: Text(D.weekdayShort[i]),
                    selected: sel,
                    onSelected: (_) => setState(() {
                      sel ? a.weekdays.remove(wd) : a.weekdays.add(wd);
                    }),
                  );
                }),
              ),
            if (a.recurrence == Recurrence.monthly)
              DropdownButtonFormField<int>(
                initialValue: a.dayOfMonth ?? 1,
                decoration: const InputDecoration(labelText: 'Day of month'),
                items: List.generate(
                    31,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text('Day ${i + 1}'))),
                onChanged: (v) => setState(() => a.dayOfMonth = v),
              ),
            if (a.recurrence == Recurrence.once)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(a.startDate == null
                    ? 'Pick a date'
                    : D.long(a.startDate!)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final d = await pickDate(context, a.startDate);
                  if (d != null) setState(() => a.startDate = d);
                },
              ),
            const SectionHeader('Reminder'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notify me'),
              subtitle: Text(a.reminderTime == null
                  ? 'No time set'
                  : 'At ${D.time(a.reminderTime!)}'),
              value: a.reminderEnabled,
              onChanged: (v) async {
                if (v && a.reminderTime == null) {
                  final t = await pickTime(context, '08:00');
                  if (t == null) return;
                  a.reminderTime = t;
                }
                setState(() => a.reminderEnabled = v);
              },
            ),
            if (a.reminderEnabled)
              OutlinedButton.icon(
                onPressed: () async {
                  final t = await pickTime(context, a.reminderTime);
                  if (t != null) setState(() => a.reminderTime = t);
                },
                icon: const Icon(Icons.schedule),
                label: Text('Change time (${D.time(a.reminderTime ?? '08:00')})'),
              ),
            SectionHeader(
              isGym ? 'Exercises' : 'Checklist items',
              action: TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add')),
            ),
            if (a.items.isEmpty)
              Text(
                isGym
                    ? 'Add each exercise with sets x reps, e.g. "Lateral raises - 3x12 @ 10kg". Each gets its own checkbox.'
                    : 'Optional sub-tasks. Each gets its own checkbox on the day.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (o, n) => setState(() {
                if (n > o) n--;
                final it = a.items.removeAt(o);
                a.items.insert(n, it);
              }),
              children: [
                for (var i = 0; i < a.items.length; i++)
                  ListTile(
                    key: ValueKey(a.items[i].id),
                    contentPadding: EdgeInsets.zero,
                    leading: ReorderableDragStartListener(
                        index: i, child: const Icon(Icons.drag_indicator)),
                    title: Text(a.items[i].title),
                    subtitle: a.items[i].detail == null
                        ? null
                        : Text(a.items[i].detail!),
                    onTap: () => _editItem(a.items[i]),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => a.items.removeAt(i)),
                    ),
                  ),
              ],
            ),
            const SectionHeader('Notes'),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Anything to remember for this activity'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save activity')),
          ],
        ),
      ),
    );
  }

  Future<(String, String?)?> _itemDialog(BuildContext context,
      {String? title, String? detail}) async {
    final t = TextEditingController(text: title);
    final d = TextEditingController(text: detail);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title == null ? 'Add item' : 'Edit item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: t,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Name', hintText: 'e.g. Overhead press'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: d,
              decoration: const InputDecoration(
                  labelText: 'Detail (optional)', hintText: 'e.g. 4x8 @ 40kg'),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK')),
        ],
      ),
    );
    if (ok != true || t.text.trim().isEmpty) return null;
    return (t.text.trim(), d.text.trim().isEmpty ? null : d.text.trim());
  }
}
