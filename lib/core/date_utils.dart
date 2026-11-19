import 'package:intl/intl.dart';

/// Date helpers. Dates are stored as ISO `yyyy-MM-dd` strings.
class D {
  static final DateFormat _iso = DateFormat('yyyy-MM-dd');
  static final DateFormat _month = DateFormat('yyyy-MM');

  static String key(DateTime d) => _iso.format(d);
  static String monthKey(DateTime d) => _month.format(d);
  static DateTime parse(String key) => _iso.parse(key);
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String todayKey() => key(today());

  static String human(DateTime d) {
    final t = today();
    final dd = DateTime(d.year, d.month, d.day);
    if (dd == t) return 'Today';
    if (dd == t.subtract(const Duration(days: 1))) return 'Yesterday';
    if (dd == t.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(d);
  }

  static String long(DateTime d) => DateFormat('EEEE, d MMMM yyyy').format(d);
  static String short(DateTime d) => DateFormat('d MMM').format(d);
  static String monthName(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String time(String hhmm) {
    final parts = hhmm.split(':');
    final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('h:mm a').format(dt);
  }

  static const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static List<DateTime> lastNDays(int n) {
    final t = today();
    return List.generate(n, (i) => t.subtract(Duration(days: n - 1 - i)));
  }

  static DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime lastOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);
}
