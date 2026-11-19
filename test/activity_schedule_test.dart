import 'package:ai_life_manager/models/activity.dart';
import 'package:flutter_test/flutter_test.dart';

Activity _make(Recurrence r,
        {List<int> weekdays = const [], int? dom, DateTime? start}) =>
    Activity(
      id: 'a',
      title: 'Test',
      category: 'Gym',
      recurrence: r,
      weekdays: weekdays,
      dayOfMonth: dom,
      startDate: start,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Activity.occursOn', () {
    test('daily occurs every day', () {
      final a = _make(Recurrence.daily);
      expect(a.occursOn(DateTime(2026, 11, 19)), isTrue);
      expect(a.occursOn(DateTime(2026, 11, 22)), isTrue);
    });

    test('weekly only on chosen weekdays', () {
      // 2026-11-19 is a Thursday (weekday 4).
      final a = _make(Recurrence.weekly, weekdays: [1, 4]);
      expect(a.occursOn(DateTime(2026, 11, 19)), isTrue); // Thu
      expect(a.occursOn(DateTime(2026, 11, 20)), isFalse); // Fri
      expect(a.occursOn(DateTime(2026, 11, 23)), isTrue); // Mon
    });

    test('monthly clamps to last day of short months', () {
      final a = _make(Recurrence.monthly, dom: 31);
      expect(a.occursOn(DateTime(2026, 1, 31)), isTrue);
      expect(a.occursOn(DateTime(2026, 2, 28)), isTrue); // Feb has 28 days
      expect(a.occursOn(DateTime(2026, 2, 27)), isFalse);
    });

    test('one-time only on its date', () {
      final a = _make(Recurrence.once, start: DateTime(2026, 12, 1));
      expect(a.occursOn(DateTime(2026, 12, 1)), isTrue);
      expect(a.occursOn(DateTime(2026, 12, 2)), isFalse);
    });

    test('recurring activities do not occur before start date', () {
      final a = _make(Recurrence.daily, start: DateTime(2026, 12, 1));
      expect(a.occursOn(DateTime(2026, 11, 30)), isFalse);
      expect(a.occursOn(DateTime(2026, 12, 1)), isTrue);
    });

    test('archived activities never occur', () {
      final a = _make(Recurrence.daily)..archived = true;
      expect(a.occursOn(DateTime(2026, 11, 19)), isFalse);
    });
  });

  test('toMap/fromMap round-trips weekdays and reminder', () {
    final a = _make(Recurrence.weekly, weekdays: [2, 5])
      ..reminderTime = '18:30'
      ..reminderEnabled = true;
    final b = Activity.fromMap(a.toMap());
    expect(b.weekdays, [2, 5]);
    expect(b.reminderTime, '18:30');
    expect(b.reminderEnabled, isTrue);
    expect(b.recurrence, Recurrence.weekly);
  });
}
