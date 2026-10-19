import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';

/// A small line chart of weight over time, drawn without extra packages.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.entries, required this.useLb});
  final List<WeightEntry> entries; // sorted oldest first
  final bool useLb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.length < 2) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Add at least 2 weights to see the chart.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: _WeightPainter(
          entries: entries,
          useLb: useLb,
          line: theme.colorScheme.primary,
          grid: theme.colorScheme.outlineVariant,
          text: theme.colorScheme.onSurfaceVariant,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter({
    required this.entries,
    required this.useLb,
    required this.line,
    required this.grid,
    required this.text,
  });

  final List<WeightEntry> entries;
  final bool useLb;
  final Color line;
  final Color grid;
  final Color text;

  double _v(WeightEntry e) => useLb ? kgToLb(e.weightKg) : e.weightKg;

  void _label(Canvas canvas, String s, Offset at, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: text, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right ? at.dx - tp.width : at.dx;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0, rightPad = 12.0, top = 12.0, bottom = 24.0;
    final w = size.width - left - rightPad;
    final h = size.height - top - bottom;

    final values = entries.map(_v).toList();
    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    if ((maxV - minV) < 0.5) {
      minV -= 0.5;
      maxV += 0.5;
    }
    final pad = (maxV - minV) * 0.1;
    minV -= pad;
    maxV += pad;

    final t0 = entries.first.date.millisecondsSinceEpoch.toDouble();
    final t1 = entries.last.date.millisecondsSinceEpoch.toDouble();
    final span = math.max(1.0, t1 - t0);

    Offset pos(WeightEntry e) {
      final x = left + (e.date.millisecondsSinceEpoch - t0) / span * w;
      final y = top + (1 - (_v(e) - minV) / (maxV - minV)) * h;
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + h * i / 3;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
      final v = maxV - (maxV - minV) * i / 3;
      _label(canvas, v.toStringAsFixed(1), Offset(left - 6, y), right: true);
    }

    _label(canvas, fmtShortDate(entries.first.date),
        Offset(left, size.height - 8));
    _label(canvas, fmtShortDate(entries.last.date),
        Offset(left + w, size.height - 8),
        right: true);

    final path = Path();
    for (var i = 0; i < entries.length; i++) {
      final p = pos(entries[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    for (final e in entries) {
      canvas.drawCircle(pos(e), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter old) =>
      old.entries != entries || old.useLb != useLb || old.line != line;
}
