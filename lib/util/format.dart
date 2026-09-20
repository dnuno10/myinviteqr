import 'package:flutter/material.dart';
import '../config.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${_months[l.month - 1]} ${l.day}, ${l.year}';
}

String fmtDateLong(DateTime d) {
  final l = d.toLocal();
  return '${_days[l.weekday - 1]}, ${_monthsLong[l.month - 1]} ${l.day}, ${l.year}';
}

String fmtTime(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
}

String fmtAgo(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60)
    return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
  if (diff.inHours < 24)
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  if (diff.inDays < 30)
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  return fmtDate(d);
}

String money(num cents) => '\$${(cents / 100).toStringAsFixed(2)}';

Color hexColor(String? hex, Color fallback) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex))
    return fallback;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

String colorHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String publicUrl(String token, {String? guest}) {
  final base = publicBaseUrl.isNotEmpty ? Uri.parse(publicBaseUrl) : Uri.base;
  return Uri(
    scheme: base.scheme.isEmpty ? 'https' : base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/',
    queryParameters: {'i': token, if (guest != null) 'g': guest},
  ).toString();
}
