import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';

/// Circular progress ring with content in the middle.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    required this.color,
    this.size = 120,
    this.stroke = 12,
    this.child,
  });

  final double value;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0.0, 1.0).toDouble(), color, stroke),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.stroke);

  final double value;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    if (value <= 0) return;
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.6), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// Simple monthly bar chart; the last bar is highlighted.
class TrendBars extends StatelessWidget {
  const TrendBars({super.key, required this.values, required this.labels, this.height = 140});

  final List<double> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(0, math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    values[i] > 0 ? moneyShort(values[i]) : '',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: i == values.length - 1 ? AppColors.text : AppColors.muted,
                      fontWeight: i == values.length - 1 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 22,
                    height: maxV <= 0 ? 4 : math.max(4, (height - 44) * values[i] / maxV),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: i == values.length - 1
                          ? const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [AppColors.accent, AppColors.accent2],
                            )
                          : null,
                      color: i == values.length - 1 ? null : AppColors.surface2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(labels[i], style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar.
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.fraction, required this.color, this.height = 6});

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: AppColors.surface2),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Donut chart of parts of a whole, with a gap between segments.
class Donut extends StatelessWidget {
  const Donut({
    super.key,
    required this.values,
    required this.colors,
    this.size = 132,
    this.stroke = 16,
    this.child,
  });

  final List<double> values;
  final List<Color> colors;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(values, colors, stroke),
        child: Center(child: child),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors, this.stroke);

  final List<double> values;
  final List<Color> colors;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final total = values.fold<double>(0, (s, v) => s + v);
    final track = Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (total <= 0) return;
    final gap = values.where((v) => v > 0).length > 1 ? 0.045 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * values[i] / total;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start + gap / 2, math.max(0.001, sweep - gap), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.values != values || old.colors != colors;
}

/// Money out vs money in per month, as paired bars.
class FlowBars extends StatelessWidget {
  const FlowBars({
    super.key,
    required this.spent,
    required this.received,
    required this.labels,
    this.height = 150,
  });

  final List<double> spent;
  final List<double> received;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = [...spent, ...received].fold<double>(0, math.max);
    final barArea = height - 28;
    double h(double v) => maxV <= 0 ? 3 : math.max(3, barArea * v / maxV);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < spent.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar(h(spent[i]), AppColors.spend, i == spent.length - 1),
                      const SizedBox(width: 4),
                      _bar(h(received[i]), AppColors.receive, i == spent.length - 1),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: i == spent.length - 1 ? AppColors.text : AppColors.muted,
                      fontWeight: i == spent.length - 1 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(double height, Color color, bool current) {
    return Container(
      width: 11,
      height: height,
      decoration: BoxDecoration(
        color: current ? color : color.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Small coloured dot + label, for chart legends.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}
