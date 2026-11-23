import 'package:intl/intl.dart';

final _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inr2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// ₹1,23,456 for whole amounts, ₹1,234.50 otherwise.
String money(double v) {
  final whole = (v - v.roundToDouble()).abs() < 0.005;
  return whole ? _inr0.format(v) : _inr2.format(v);
}

/// Short form for charts: ₹950, ₹12.5k, ₹1.2L.
String moneyShort(double v) {
  if (v >= 100000) return '₹${_trim(v / 100000)}L';
  if (v >= 1000) return '₹${_trim(v / 1000)}k';
  return '₹${v.round()}';
}

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String monthTitle(DateTime m) => DateFormat('MMMM yyyy').format(m);
String monthShort(DateTime m) => DateFormat('MMM').format(m);
String dayMonth(DateTime d) => DateFormat('d MMM').format(d);
String timeOfDay(DateTime d) => DateFormat('h:mm a').format(d);

String dayHeader(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (d.year == now.year) return DateFormat('EEE, d MMM').format(d);
  return DateFormat('EEE, d MMM yyyy').format(d);
}

String titleCase(String s) {
  return s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w.length <= 3 && w == w.toUpperCase() ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
