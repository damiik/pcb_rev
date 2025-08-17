import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../data/logical_models.dart';
import 'package:pcb_rev/features/symbol_library/data/kicad_symbol_loader.dart';
import 'package:pcb_rev/features/symbol_library/presentation/kicad_symbol_renderer.dart';

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
    case 'ic 8pin':
      drawIC8pin(canvas, pos, component, componentPaint, componentFillPaint);
      break;
    case 'ic 16pin':
      drawIC16pin(canvas, pos, component, componentPaint, componentFillPaint);
      break;
    case 'ic 20pin':
      drawIC20pin(canvas, pos, component, componentPaint, componentFillPaint);
      break;
    case 'ic 24pin':
      drawIC24pin(canvas, pos, component, componentPaint, componentFillPaint);
      break;
    case 'ic 28pin':
      drawIC28pin(canvas, pos, component, componentPaint, componentFillPaint);
      break;
    case 'ic 32pin':
      drawIC32pin(canvas, pos, component, componentPaint, componentFillPaint);
      break;
    case 'ic 48pin q':
      drawIC48pinQ(canvas, pos, component, componentPaint, componentFillPaint);
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

void drawIC8pin(
  ui.Canvas canvas,
  Offset pos,
  LogicalComponent component,
  Paint paint,
  Paint fillPaint,
) {
  final rect = Rect.fromCenter(center: pos, width: 40, height: 20);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);
  for (int i = 0; i < 4; i++) {
    canvas.drawLine(
      pos + Offset(-15 + i * 10, -10),
      pos + Offset(-15 + i * 10, -20),
      paint,
    );
    canvas.drawLine(
      pos + Offset(-15 + i * 10, 10),
      pos + Offset(-15 + i * 10, 20),
      paint,
    );
  }
}

void drawIC16pin(
  ui.Canvas canvas,
  Offset pos,
  LogicalComponent component,
  Paint paint,
  Paint fillPaint,
) {
  final rect = Rect.fromCenter(center: pos, width: 80, height: 20);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);
  for (int i = 0; i < 8; i++) {
    canvas.drawLine(
      pos + Offset(-35 + i * 10, -10),
      pos + Offset(-35 + i * 10, -20),
      paint,
    );
    canvas.drawLine(
      pos + Offset(-35 + i * 10, 10),
      pos + Offset(-35 + i * 10, 20),
      paint,
    );
  }
}

void drawIC20pin(
  ui.Canvas canvas,
  Offset pos,
  LogicalComponent component,
  Paint paint,
  Paint fillPaint,
) {
  final rect = Rect.fromCenter(center: pos, width: 100, height: 20);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);
  for (int i = 0; i < 10; i++) {
    canvas.drawLine(
      pos + Offset(-45 + i * 10, -10),
      pos + Offset(-45 + i * 10, -20),
      paint,
    );
    canvas.drawLine(
      pos + Offset(-45 + i * 10, 10),
      pos + Offset(-45 + i * 10, 20),
      paint,
    );
  }
}

void drawIC24pin(
  ui.Canvas canvas,
  Offset pos,
  LogicalComponent component,
  Paint paint,
  Paint fillPaint,
) {
  final rect = Rect.fromCenter(center: pos, width: 120, height: 20);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);
  for (int i = 0; i < 12; i++) {
    canvas.drawLine(
      pos + Offset(-55 + i * 10, -10),
      pos + Offset(-55 + i * 10, -20),
      paint,
    );
    canvas.drawLine(
      pos + Offset(-55 + i * 10, 10),
      pos + Offset(-55 + i * 10, 20),
      paint,
    );
  }
}

void drawIC28pin(
  ui.Canvas canvas,
  Offset pos,
  LogicalComponent component,
  Paint paint,
  Paint fillPaint,
) {
  final rect = Rect.fromCenter(center: pos, width: 140, height: 20);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);
  for (int i = 0; i < 14; i++) {
    canvas.drawLine(
      pos + Offset(-65 + i * 10, -10),
      pos + Offset(-65 + i * 10, -20),
      paint,
    );
    canvas.drawLine(
      pos + Offset(-65 + i * 10, 10),
      pos + Offset(-65 + i * 10, 20),
      paint,
    );
  }
}

void drawIC32pin(
  ui.Canvas canvas,
  Offset pos,
  LogicalComponent component,
  Paint paint,
  Paint fillPaint,
) {
  final rect = Rect.fromCenter(center: pos, width: 160, height: 20);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);
  for (int i = 0; i < 16; i++) {
    canvas.drawLine(
      pos + Offset(-75 + i * 10, -10),
      pos + Offset(-75 + i * 10, -20),
      paint,
    );
    canvas.drawLine(
      pos + Offset(-75 + i * 10, 10),
      pos + Offset(-75 + i * 10, 20),
      paint,
    );
  }
}

void drawIC48pinQ(
  ui.Canvas canvas,
  Offset pos,
  LogicalComponent component,
  Paint paint,
  Paint fillPaint,
) {
  final rect = Rect.fromCenter(center: pos, width: 120, height: 120);
  canvas.drawRect(rect, fillPaint);
  canvas.drawRect(rect, paint);
  for (int i = 0; i < 12; i++) {
    canvas.drawLine(
      pos + Offset(-60, -55 + i * 10),
      pos + Offset(-70, -55 + i * 10),
      paint,
    );
    canvas.drawLine(
      pos + Offset(60, -55 + i * 10),
      pos + Offset(70, -55 + i * 10),
      paint,
    );
    canvas.drawLine(
      pos + Offset(-55 + i * 10, -60),
      pos + Offset(-55 + i * 10, -70),
      paint,
    );
    canvas.drawLine(
      pos + Offset(-55 + i * 10, 60),
      pos + Offset(-55 + i * 10, 70),
      paint,
    );
  }
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
