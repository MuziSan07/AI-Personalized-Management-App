import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/date_utils.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../services/notification_service.dart';

class ActivityProvider extends ChangeNotifier {
  ActivityProvider(this._repo);

  final ActivityRepository _repo;
  final _uuid = const Uuid();

  List<Activity> _all = [];
  DateTime _selected = D.today();
  List<Completion> _completions = [];
  bool loading = true;

  List<Activity> get all => _all;
  DateTime get selectedDate => _selected;
  String get selectedKey => D.key(_selected);

  Future<void> load() async {
    _all = await _repo.getAll();
    _completions = await _repo.completionsOn(selectedKey);
    loading = false;
    notifyListeners();
  }

  Future<void> selectDate(DateTime d) async {
    _selected = DateTime(d.year, d.month, d.day);
    _completions = await _repo.completionsOn(selectedKey);
    notifyListeners();
  }

  /// Activities scheduled on the selected date.
  List<Activity> get forSelectedDate =>
      _all.where((a) => a.occursOn(_selected)).toList();

  List<Activity> forDate(DateTime d) =>
      _all.where((a) => a.occursOn(d)).toList();

  Activity? byId(String id) {
    for (final a in _all) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool isItemDone(String activityId, String itemId) => _completions
      .any((c) => c.activityId == activityId && c.itemId == itemId);

  bool isActivityDone(Activity a) {
    if (a.items.isEmpty) {
      return _completions
          .any((c) => c.activityId == a.id && c.itemId == null);
    }
    return a.items.every((i) => isItemDone(a.id, i.id));
  }

  int doneCount(Activity a) => a.items.isEmpty
      ? (isActivityDone(a) ? 1 : 0)
      : a.items.where((i) => isItemDone(a.id, i.id)).length;

  double progress(Activity a) {
    if (a.items.isEmpty) return isActivityDone(a) ? 1 : 0;
    return doneCount(a) / a.items.length;
  }

  /// Share of today's scheduled activities fully completed.
  double get dayCompletion {
    final list = forSelectedDate;
    if (list.isEmpty) return 0;
    return list.where(isActivityDone).length / list.length;
  }

  Future<void> toggleItem(Activity a, ActivityItem item) async {
    if (isItemDone(a.id, item.id)) {
      await _repo.removeCompletion(
          activityId: a.id, itemId: item.id, date: selectedKey);
    } else {
      await _repo.addCompletion(Completion(
        id: _uuid.v4(),
        activityId: a.id,
        itemId: item.id,
        date: selectedKey,
        completedAt: DateTime.now(),
      ));
    }
    _completions = await _repo.completionsOn(selectedKey);
    notifyListeners();
  }

  Future<void> toggleActivity(Activity a) async {
    final done = isActivityDone(a);
    if (done) {
      await _repo.clearCompletions(a.id, selectedKey);
    } else if (a.items.isEmpty) {
      await _repo.addCompletion(Completion(
        id: _uuid.v4(),
        activityId: a.id,
        date: selectedKey,
        completedAt: DateTime.now(),
      ));
    } else {
      for (final i in a.items) {
        if (!isItemDone(a.id, i.id)) {
          await _repo.addCompletion(Completion(
            id: _uuid.v4(),
            activityId: a.id,
            itemId: i.id,
            date: selectedKey,
            completedAt: DateTime.now(),
          ));
        }
      }
    }
    _completions = await _repo.completionsOn(selectedKey);
    notifyListeners();
  }

  Activity newActivity() => Activity(
        id: _uuid.v4(),
        title: '',
        category: 'Personal',
        createdAt: DateTime.now(),
        items: [],
      );

  ActivityItem newItem(String activityId, String title, {String? detail}) =>
      ActivityItem(
          id: _uuid.v4(), activityId: activityId, title: title, detail: detail);

  Future<void> save(Activity a) async {
    await _repo.upsert(a);
    await NotificationService.instance.scheduleActivity(a);
    await load();
  }

  Future<void> delete(Activity a) async {
    await NotificationService.instance.cancelActivity(a.id);
    await _repo.delete(a.id);
    await load();
  }

  Future<void> rescheduleAll() async {
    for (final a in _all) {
      await NotificationService.instance.scheduleActivity(a);
    }
  }

  /// Completion ratio per day for the last [days] days (for streak charts).
  Future<List<double>> history(int days) async {
    final dates = D.lastNDays(days);
    final comps =
        await _repo.completionsBetween(D.key(dates.first), D.key(dates.last));
    return dates.map((d) {
      final key = D.key(d);
      final scheduled = _all.where((a) => a.occursOn(d)).toList();
      if (scheduled.isEmpty) return 0.0;
      var done = 0;
      for (final a in scheduled) {
        final mine = comps.where((c) => c.activityId == a.id && c.date == key);
        if (a.items.isEmpty) {
          if (mine.any((c) => c.itemId == null)) done++;
        } else if (a.items.every((i) => mine.any((c) => c.itemId == i.id))) {
          done++;
        }
      }
      return done / scheduled.length;
    }).toList();
  }

  /// Compact text summary for the AI context.
  String summaryForAi() {
    final today = forDate(D.today());
    final b = StringBuffer();
    b.writeln('Activities scheduled today (${today.length}):');
    for (final a in today) {
      final status = isActivityDone(a) ? 'DONE' : '${doneCount(a)}/${a.items.isEmpty ? 1 : a.items.length}';
      b.writeln('- ${a.title} [${a.category}, ${a.scheduleLabel}] $status'
          '${a.items.isEmpty ? '' : ': ${a.items.map((i) => i.title + (i.detail == null ? '' : ' (${i.detail})')).join(', ')}'}');
    }
    final others = _all.where((a) => !today.contains(a)).toList();
    if (others.isNotEmpty) {
      b.writeln('Other recurring activities: ${others.map((a) => '${a.title} (${a.scheduleLabel})').join('; ')}');
    }
    return b.toString();
  }
}
