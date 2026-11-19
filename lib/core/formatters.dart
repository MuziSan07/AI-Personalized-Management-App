import 'package:intl/intl.dart';

class Fmt {
  static String money(double v, String currency) {
    final f = NumberFormat.currency(
        symbol: '$currency ', decimalDigits: v == v.roundToDouble() ? 0 : 2);
    return f.format(v);
  }

  static String compact(double v) => NumberFormat.compact().format(v);
  static String num0(num v) => NumberFormat('#,##0').format(v);
  static String num1(num v) => NumberFormat('#,##0.#').format(v);
  static String pct(double ratio) => '${(ratio * 100).clamp(0, 999).round()}%';
}
