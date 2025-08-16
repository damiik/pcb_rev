import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../data/logical_models.dart';

void drawComponentSymbol(
  ui.Canvas canvas,
  LogicalComponent component,
  Offset pos,
  Paint paint,
  Paint fillPaint, {
  bool isSelected = false,
}) {
  final componentPaint = paint..color = isSelected ? Colors.blue : Colors.white;
  final componentFillPaint = fillPaint..color = Colors.grey[900]!;

  switch (component.type.toLowerCase()) {
    case 'resistor':
      drawResistor(canvas, pos, componentPaint, componentFillPaint);
      break;
    case 'capacitor':
      drawCapacitor(canvas, pos, componentPaint, componentFillPaint);
      break;
    case 'ic':
    case 'chip':
      drawIC(canvas, pos, component, componentPaint, componentFillPaint);
      break;
    case 'transistor':
      drawTransistor(canvas, pos, componentPaint, componentFillPaint);
      break;
    case 'inductor':
      drawInductor(canvas, pos, componentPaint, componentFillPaint);
      break;
    case 'diode':
      drawDiode(canvas, pos, componentPaint, componentFillPaint);
      break;
    default:
      drawGenericComponent(canvas, pos, componentPaint, componentFillPaint);
  }
}

void drawResistor(ui.Canvas canvas, Offset pos, Paint paint, Paint fillPaint) {
  final rect = Rect.fromCenter(center: pos, width: 20, height: 8);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);
  canvas.drawLine(pos + Offset(-20, 0), pos + Offset(-10, 0), paint);
  canvas.drawLine(pos + Offset(20, 0), pos + Offset(10, 0), paint);
}

void drawCapacitor(ui.Canvas canvas, Offset pos, Paint paint, Paint fillPaint) {
  canvas.drawLine(pos + Offset(-4, -10), pos + Offset(-4, 10), paint);
  canvas.drawLine(pos + Offset(4, -10), pos + Offset(4, 10), paint);
  canvas.drawLine(pos + Offset(-20, 0), pos + Offset(-4, 0), paint);
  canvas.drawLine(pos + Offset(20, 0), pos + Offset(4, 0), paint);
}

void drawIC(
  ui.Canvas canvas,
  Offset pos,
  LogicalComponent component,
  Paint paint,
  Paint fillPaint,
) {
  final pinCount = component.pins.length;
  final width = 40.0;
  final height = math.max(20.0, (pinCount / 2).ceil() * 10.0);

  final rect = Rect.fromCenter(center: pos, width: width, height: height);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);

  // Draw notch
  canvas.drawCircle(pos + Offset(-width / 2, 0), 3, paint);
}

void drawInductor(ui.Canvas canvas, Offset pos, Paint paint, Paint fillPaint) {
  final path = Path();
  for (int i = 0; i < 4; i++) {
    final x = pos.dx - 15 + i * 10;
    path.addArc(
      Rect.fromCircle(center: Offset(x, pos.dy), radius: 5),
      math.pi,
      math.pi,
    );
  }
  canvas.drawPath(path, paint);
}

void drawDiode(ui.Canvas canvas, Offset pos, Paint paint, Paint fillPaint) {
  final path = Path();
  path.moveTo(pos.dx - 10, pos.dy - 8);
  path.lineTo(pos.dx + 10, pos.dy);
  path.lineTo(pos.dx - 10, pos.dy + 8);
  path.close();
  canvas.drawPath(path, fillPaint);
  canvas.drawPath(path, paint);
  canvas.drawLine(pos + Offset(10, -8), pos + Offset(10, 8), paint);
}

void drawTransistor(
  ui.Canvas canvas,
  Offset pos,
  Paint paint,
  Paint fillPaint,
) {
  canvas.drawCircle(pos, 15, fillPaint);
  canvas.drawCircle(pos, 15, paint);

  // Draw base
  canvas.drawLine(pos + Offset(-15, 0), pos + Offset(-5, 0), paint);
  canvas.drawLine(pos + Offset(-5, -8), pos + Offset(-5, 8), paint);

  // Draw collector and emitter
  canvas.drawLine(pos + Offset(-5, -4), pos + Offset(5, -10), paint);
  canvas.drawLine(pos + Offset(-5, 4), pos + Offset(5, 10), paint);
}

void drawGenericComponent(
  ui.Canvas canvas,
  Offset pos,
  Paint paint,
  Paint fillPaint,
) {
  final rect = Rect.fromCenter(center: pos, width: 30, height: 20);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);
}
