import 'package:flutter/material.dart';

import '../core/theme.dart';

enum Recurrence { once, daily, weekly, monthly }

extension RecurrenceX on Recurrence {
  String get label => switch (this) {
        Recurrence.once => 'One time',
        Recurrence.daily => 'Daily',
        Recurrence.weekly => 'Weekly',
        Recurrence.monthly => 'Monthly',
      };
}

class ActivityItem {
  ActivityItem({
    required this.id,
    required this.activityId,
    required this.title,
    this.detail,
    this.sortOrder = 0,
  });

  final String id;
  final String activityId;
  String title;
  String? detail;
  int sortOrder;

  Map<String, Object?> toMap() => {
        'id': id,
        'activity_id': activityId,
        'title': title,
        'detail': detail,
        'sort_order': sortOrder,
      };

  factory ActivityItem.fromMap(Map<String, Object?> m) => ActivityItem(
        id: m['id'] as String,
        activityId: m['activity_id'] as String,
        title: m['title'] as String,
        detail: m['detail'] as String?,
        sortOrder: (m['sort_order'] as int?) ?? 0,
      );
}

class Activity {
  Activity({
    required this.id,
    required this.title,
    required this.category,
    this.notes,
    this.recurrence = Recurrence.daily,
    this.weekdays = const [],
    this.dayOfMonth,
    this.startDate,
    this.reminderTime,
    this.reminderEnabled = false,
    this.colorValue = 0xFF5B5FEF,
    this.icon = 'check',
    this.archived = false,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  String title;
  String category;
  String? notes;
  Recurrence recurrence;
  /// 1 = Monday ... 7 = Sunday (DateTime.weekday).
  List<int> weekdays;
  int? dayOfMonth;
  /// For one-time activities: the scheduled date. For recurring ones: first
  /// date the activity is active (optional).
  DateTime? startDate;
  /// "HH:mm" 24h.
  String? reminderTime;
  bool reminderEnabled;
  int colorValue;
  String icon;
  bool archived;
  final DateTime createdAt;
  List<ActivityItem> items;

  Color get color => Color(colorValue);
  IconData get iconData => kActivityIcons[icon] ?? Icons.check_circle_outline;

  /// Whether this activity is scheduled on [date].
  bool occursOn(DateTime date) {
    if (archived) return false;
    final d = DateTime(date.year, date.month, date.day);
    if (startDate != null) {
      final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
      if (recurrence == Recurrence.once) return s == d;
      if (d.isBefore(s)) return false;
    } else if (recurrence == Recurrence.once) {
      return false;
    }
    switch (recurrence) {
      case Recurrence.daily:
        return true;
      case Recurrence.weekly:
        return weekdays.contains(d.weekday);
      case Recurrence.monthly:
        final dom = dayOfMonth ?? 1;
        final last = DateTime(d.year, d.month + 1, 0).day;
        return d.day == (dom > last ? last : dom);
      case Recurrence.once:
        return false;
    }
  }

  String get scheduleLabel {
    switch (recurrence) {
      case Recurrence.daily:
        return 'Every day';
      case Recurrence.weekly:
        if (weekdays.length == 7) return 'Every day';
        const n = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final s = [...weekdays]..sort();
        return s.map((w) => n[w - 1]).join(', ');
      case Recurrence.monthly:
        return 'Monthly on day ${dayOfMonth ?? 1}';
      case Recurrence.once:
        return startDate == null ? 'One time' : 'Once';
    }
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'notes': notes,
        'recurrence': recurrence.name,
        'weekdays': weekdays.join(','),
        'day_of_month': dayOfMonth,
        'start_date': startDate?.toIso8601String(),
        'reminder_time': reminderTime,
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'color': colorValue,
        'icon': icon,
        'archived': archived ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Activity.fromMap(Map<String, Object?> m,
          {List<ActivityItem> items = const []}) =>
      Activity(
        id: m['id'] as String,
        title: m['title'] as String,
        category: m['category'] as String,
        notes: m['notes'] as String?,
        recurrence: Recurrence.values
            .firstWhere((r) => r.name == m['recurrence'], orElse: () => Recurrence.daily),
        weekdays: ((m['weekdays'] as String?) ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList(),
        dayOfMonth: m['day_of_month'] as int?,
        startDate: m['start_date'] == null
            ? null
            : DateTime.parse(m['start_date'] as String),
        reminderTime: m['reminder_time'] as String?,
        reminderEnabled: (m['reminder_enabled'] as int? ?? 0) == 1,
        colorValue: m['color'] as int,
        icon: m['icon'] as String,
        archived: (m['archived'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        items: items,
      );
}

class Completion {
  Completion({
    required this.id,
    required this.activityId,
    this.itemId,
    required this.date,
    required this.completedAt,
  });

  final String id;
  final String activityId;
  final String? itemId;
  final String date;
  final DateTime completedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'activity_id': activityId,
        'item_id': itemId,
        'date': date,
        'completed_at': completedAt.toIso8601String(),
      };

  factory Completion.fromMap(Map<String, Object?> m) => Completion(
        id: m['id'] as String,
        activityId: m['activity_id'] as String,
        itemId: m['item_id'] as String?,
        date: m['date'] as String,
        completedAt: DateTime.parse(m['completed_at'] as String),
      );
}
