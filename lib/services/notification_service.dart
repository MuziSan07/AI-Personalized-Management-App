import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/activity.dart';

/// Schedules local reminders for activities and the daily summary.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'reminders',
    'Reminders',
    description: 'Activity reminders and daily summaries',
    importance: Importance.high,
  );

  static const int dailySummaryId = 1;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone fallback to UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    _ready = true;
  }

  Future<bool> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? true;
      await android.requestExactAlarmsPermission();
      return granted;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// Stable, int32-safe id space per activity (8 slots each).
  static int _baseId(String activityId) =>
      (activityId.hashCode & 0x07FFFFFF) * 8 + 16;

  (int, int) _parseTime(String hhmm) {
    final p = hhmm.split(':');
    return (int.parse(p[0]), int.parse(p[1]));
  }

  tz.TZDateTime _nextDaily(int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  tz.TZDateTime _nextWeekly(int weekday, int h, int m) {
    var t = _nextDaily(h, m);
    while (t.weekday != weekday) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  tz.TZDateTime _nextMonthly(int day, int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var year = now.year, month = now.month;
    for (var i = 0; i < 13; i++) {
      final last = DateTime(year, month + 1, 0).day;
      final d = day > last ? last : day;
      final t = tz.TZDateTime(tz.local, year, month, d, h, m);
      if (t.isAfter(now)) return t;
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    return _nextDaily(h, m);
  }

  Future<void> cancelActivity(String activityId) async {
    await init();
    final base = _baseId(activityId);
    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(id: base + i);
    }
  }

  Future<void> scheduleActivity(Activity a) async {
    await init();
    await cancelActivity(a.id);
    if (!a.reminderEnabled || a.reminderTime == null || a.archived) return;
    final (h, m) = _parseTime(a.reminderTime!);
    final base = _baseId(a.id);
    final title = a.title;
    final body = a.items.isEmpty
        ? 'Time for ${a.category.toLowerCase()}: $title'
        : '${a.items.length} items to check off today';

    Future<void> put(int id, tz.TZDateTime when, DateTimeComponents? match) =>
        _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: match,
          payload: a.id,
        );

    switch (a.recurrence) {
      case Recurrence.daily:
        await put(base, _nextDaily(h, m), DateTimeComponents.time);
      case Recurrence.weekly:
        for (final wd in a.weekdays) {
          await put(base + wd, _nextWeekly(wd, h, m),
              DateTimeComponents.dayOfWeekAndTime);
        }
      case Recurrence.monthly:
        await put(base, _nextMonthly(a.dayOfMonth ?? 1, h, m),
            DateTimeComponents.dayOfMonthAndTime);
      case Recurrence.once:
        final s = a.startDate;
        if (s == null) return;
        final when = tz.TZDateTime(tz.local, s.year, s.month, s.day, h, m);
        if (when.isAfter(tz.TZDateTime.now(tz.local))) {
          await put(base, when, null);
        }
    }
  }

  Future<void> scheduleDailySummary(
      {required bool enabled, required String time}) async {
    await init();
    await _plugin.cancel(id: dailySummaryId);
    if (!enabled) return;
    final (h, m) = _parseTime(time);
    await _plugin.zonedSchedule(
      id: dailySummaryId,
      title: 'Your day at a glance',
      body: 'Open AI Life Manager to review your activities, goals and budget.',
      scheduledDate: _nextDaily(h, m),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showNow(String title, String body) async {
    await init();
    await _plugin.show(id: 0, title: title, body: body, notificationDetails: _details);
  }

  Future<List<PendingNotificationRequest>> pending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }
}
