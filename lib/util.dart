import 'package:flutter/material.dart';

import 'models.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String fmtShortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

String fmtMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $suffix';
}

String fmtTime(DateTime d) => fmtMinutes(d.hour * 60 + d.minute);

/// "Today", "Tomorrow", "In 3 days", "2 days overdue".
String relativeDay(DateTime target, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = dateOnly(target).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1) return 'In $diff days';
  return '${-diff} days overdue';
}

String ageText(DateTime? birth) {
  if (birth == null) return '';
  final now = DateTime.now();
  var months = (now.year - birth.year) * 12 + now.month - birth.month;
  if (now.day < birth.day) months -= 1;
  if (months < 0) return '';
  if (months < 12) return '$months mo';
  final y = months ~/ 12;
  final m = months % 12;
  return m == 0 ? '$y yr' : '$y yr $m mo';
}

double kgToLb(double kg) => kg * 2.20462;
double lbToKg(double lb) => lb / 2.20462;

String fmtWeight(double kg, bool useLb) {
  final v = useLb ? kgToLb(kg) : kg;
  return '${v.toStringAsFixed(v < 10 ? 2 : 1)} ${useLb ? 'lb' : 'kg'}';
}

IconData speciesIcon(Species s) => Icons.pets;

String speciesLabel(Species s) => switch (s) {
      Species.dog => 'Dog',
      Species.cat => 'Cat',
      Species.other => 'Other',
    };

Future<DateTime?> pickDate(BuildContext context, DateTime initial,
    {DateTime? first, DateTime? last}) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(1990),
    lastDate: last ?? DateTime(DateTime.now().year + 10),
  );
}

Future<int?> pickMinutes(BuildContext context, int initialMinutes) async {
  final t = await showTimePicker(
    context: context,
    initialTime:
        TimeOfDay(hour: initialMinutes ~/ 60, minute: initialMinutes % 60),
  );
  if (t == null) return null;
  return t.hour * 60 + t.minute;
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String ok = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String fmtMoney(double v, String currency) {
  final whole = v == v.roundToDouble();
  final n = whole ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  // Add thousands separators.
  final parts = n.split('.');
  final buf = StringBuffer();
  final s = parts[0];
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final out = parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
  return '$currency$out';
}

const currencies = [r'$', '€', '£', '৳', '₹', 'A\$', 'C\$', '¥', 'R\$', '₱'];
