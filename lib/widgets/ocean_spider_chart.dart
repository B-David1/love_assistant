import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/ocean_scores.dart';

class OceanSpiderChart extends StatelessWidget {
  final OceanScores scores;

  /// The fixed target polygon (dashed grey line, default 75/25).
  final OceanScores? targetScores;

  /// Quiz-projected scores. When provided, draws a second dashed polygon
  /// in pink/purple to show the suggested change direction.
  final OceanScores? projectedScores;

  final double size;

  const OceanSpiderChart({
    super.key,
    required this.scores,
    this.targetScores,
    this.projectedScores,
    this.size = 250,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SpiderChartPainter(
          scores: scores,
          targetScores: targetScores ?? OceanScores(
            openness: 75.0,
            conscientiousness: 75.0,
            extraversion: 75.0,
            agreeableness: 75.0,
            neuroticism: 25.0,
          ),
          projectedScores: projectedScores,
        ),
      ),
    );
  }
}

class _SpiderChartPainter extends CustomPainter {
  final OceanScores scores;
  final OceanScores targetScores;
  final OceanScores? projectedScores;

  final List<String> traits = [
    'Openness',
    'Conscientiousness',
    'Extraversion',
    'Agreeableness',
    'Emotional\nStability',
  ];

  List<double> get normalizedScores => [
    scores.openness / 100,
    scores.conscientiousness / 100,
    scores.extraversion / 100,
    scores.agreeableness / 100,
    (100 - scores.neuroticism) / 100,
  ];

  List<double> get normalizedTargets => [
    targetScores.openness / 100,
    targetScores.conscientiousness / 100,
    targetScores.extraversion / 100,
    targetScores.agreeableness / 100,
    (100 - targetScores.neuroticism) / 100,
  ];

  List<double>? get normalizedProjected => projectedScores == null ? null : [
    projectedScores!.openness / 100,
    projectedScores!.conscientiousness / 100,
    projectedScores!.extraversion / 100,
    projectedScores!.agreeableness / 100,
    (100 - projectedScores!.neuroticism) / 100,
  ];

  _SpiderChartPainter({
    required this.scores,
    required this.targetScores,
    this.projectedScores,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;
    final angles = List.generate(5, (i) => i * (2 * math.pi / 5) - math.pi / 2);

    // ── Grid ──────────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final circleRadius = radius * (i / 4);
      canvas.drawCircle(center, circleRadius, gridPaint);

      final textSpan = TextSpan(
        text: (i * 25).toString(),
        style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(center.dx + 5, center.dy - circleRadius - 10));
    }

    // ── Radial lines + labels ─────────────────────────────────────────────
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Colors.grey.shade700,
    );

    for (int i = 0; i < 5; i++) {
      final angle = angles[i];
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, endPoint, gridPaint);

      final labelOffset = Offset(
        center.dx + (radius + 15) * math.cos(angle),
        center.dy + (radius + 15) * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(text: traits[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(
        labelOffset.dx - tp.width / 2,
        labelOffset.dy - tp.height / 2,
      ));
    }

    // ── Target polygon (dashed grey) ─────────────────────────────────────
    _drawDashedPolygon(
      canvas, center, radius, angles,
      normalizedTargets,
      color: Colors.grey.shade400,
      strokeWidth: 2,
      dashLength: 8,
      gapLength: 6,
      fillColor: null,
    );

    // ── Quiz projection polygon (dotted, colored) ─────────────────────────
    // Drawn BEFORE the main polygon so it sits underneath.
    final projected = normalizedProjected;
    if (projected != null) {
      _drawDashedPolygon(
        canvas, center, radius, angles,
        projected,
        color: Colors.deepPurple.shade300,
        strokeWidth: 2.5,
        dashLength: 4,
        gapLength: 4,
        fillColor: Colors.deepPurple.shade100.withOpacity(0.18),
      );
    }

    // ── Actual data polygon ───────────────────────────────────────────────
    final values = normalizedScores;
    final dataPath = Path();
    for (int i = 0; i < 5; i++) {
      final pt = Offset(
        center.dx + radius * values[i] * math.cos(angles[i]),
        center.dy + radius * values[i] * math.sin(angles[i]),
      );
      i == 0 ? dataPath.moveTo(pt.dx, pt.dy) : dataPath.lineTo(pt.dx, pt.dy);
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = Colors.pink.shade100.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = Colors.pink.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Data points
    final pointFill = Paint()..color = Colors.pink.shade700..style = PaintingStyle.fill;
    final pointInner = Paint()..color = Colors.white..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final pt = Offset(
        center.dx + radius * values[i] * math.cos(angles[i]),
        center.dy + radius * values[i] * math.sin(angles[i]),
      );
      canvas.drawCircle(pt, 4, pointFill);
      canvas.drawCircle(pt, 2, pointInner);
    }
  }

  void _drawDashedPolygon(
    Canvas canvas,
    Offset center,
    double radius,
    List<double> angles,
    List<double> values, {
    required Color color,
    required double strokeWidth,
    required double dashLength,
    required double gapLength,
    Color? fillColor,
  }) {
    if (fillColor != null) {
      final fillPath = Path();
      for (int i = 0; i < 5; i++) {
        final pt = Offset(
          center.dx + radius * values[i] * math.cos(angles[i]),
          center.dy + radius * values[i] * math.sin(angles[i]),
        );
        i == 0 ? fillPath.moveTo(pt.dx, pt.dy) : fillPath.lineTo(pt.dx, pt.dy);
      }
      fillPath.close();
      canvas.drawPath(fillPath, Paint()..color = fillColor..style = PaintingStyle.fill);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final a1 = angles[i];
      final a2 = angles[(i + 1) % 5];
      final start = Offset(
        center.dx + radius * values[i] * math.cos(a1),
        center.dy + radius * values[i] * math.sin(a1),
      );
      final end = Offset(
        center.dx + radius * values[(i + 1) % 5] * math.cos(a2),
        center.dy + radius * values[(i + 1) % 5] * math.sin(a2),
      );
      _drawDashedLine(canvas, start, end, paint, dashLength, gapLength);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      double dashLength, double gapLength) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;
    final unitX = dx / distance;
    final unitY = dy / distance;
    double t = 0;
    bool drawing = true;
    while (t < distance) {
      final segLen = drawing ? dashLength : gapLength;
      final tEnd = (t + segLen).clamp(0.0, distance);
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + unitX * t, start.dy + unitY * t),
          Offset(start.dx + unitX * tEnd, start.dy + unitY * tEnd),
          paint,
        );
      }
      t = tEnd;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
