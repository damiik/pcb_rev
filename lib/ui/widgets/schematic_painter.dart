// lib/ui/widgets/schematic_painter.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/pcb_board.dart';
import '../../models/pcb_models.dart';

// Grid painter for schematic view
class GridPainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 0.5;

    const gridSize = 20.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Schematic renderer
class SchematicPainter extends CustomPainter {
  final PCBBoard board;
  final Component? draggingComponent;
  final Offset? mousePosition;
  final bool showComponents;
  final bool showNets;
  final Component? selectedComponent;
  final Net? selectedNet;

  SchematicPainter({
    required this.board,
    this.draggingComponent,
    this.mousePosition,
    required this.showComponents,
    required this.showNets,
    this.selectedComponent,
    this.selectedNet,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Draw nets (connections) first
    if (showNets) {
      _drawNets(canvas);
    }

    // Draw components on top
    if (showComponents) {
      _drawComponents(canvas);
    }

    // Draw dragging component
    if (draggingComponent != null && mousePosition != null) {
      final newPosition = Component(
        id: draggingComponent!.id,
        type: draggingComponent!.type,
        value: draggingComponent!.value,
        position: Position(x: mousePosition!.dx, y: mousePosition!.dy),
        pins: draggingComponent!.pins,
        layer: draggingComponent!.layer,
      );
      _drawComponent(canvas, newPosition);
    }
  }

  void _drawNets(ui.Canvas canvas) {
    final netPaint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final net in board.nets.values) {
      // Set color based on net type and selection
      if (net == selectedNet) {
        netPaint.color = Colors.yellow;
        netPaint.strokeWidth = 3.0;
      } else if (net.name == 'VCC' || net.name == 'VDD') {
        netPaint.color = Colors.red;
      } else if (net.name == 'GND' || net.name == 'VSS') {
        netPaint.color = Colors.black;
      } else {
        netPaint.color = Colors.green;
      }

      // Draw connections between pins
      final positions = <Offset>[];
      for (final connection in net.connections) {
        final component = board.components[connection.componentId];
        if (component != null) {
          final pin = component.pins[connection.pinId];
          if (pin != null) {
            positions.add(Offset(pin.position.x, pin.position.y));
          }
        }
      }

      // Draw lines between connected pins
      if (positions.length >= 2) {
        final path = Path();
        path.moveTo(positions.first.dx, positions.first.dy);

        // Use Manhattan routing for more PCB-like appearance
        for (int i = 1; i < positions.length; i++) {
          final current = positions[i - 1];
          final next = positions[i];

          // Draw L-shaped connection
          path.lineTo(next.dx, current.dy);
          path.lineTo(next.dx, next.dy);
        }

        canvas.drawPath(path, netPaint);
      }

      // Draw junction dots at connection points
      final junctionPaint = Paint()
        ..color = netPaint.color
        ..style = PaintingStyle.fill;

      for (final pos in positions) {
        canvas.drawCircle(pos, 3, junctionPaint);
      }
    }
  }

  void _drawComponents(ui.Canvas canvas) {
    for (final component in board.components.values) {
      _drawComponent(canvas, component);
    }
  }

  void _drawComponent(ui.Canvas canvas, Component component) {
    final isSelected = component == selectedComponent;
    final paint = Paint()
      ..color = isSelected ? Colors.blue : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.0;

    final fillPaint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.fill;

    final pos = Offset(component.position.x, component.position.y);

    // Draw component based on type
    switch (component.type.toLowerCase()) {
      case 'resistor':
        _drawResistor(canvas, pos, paint, fillPaint);
        break;
      case 'capacitor':
        _drawCapacitor(canvas, pos, paint, fillPaint);
        break;
      case 'ic':
      case 'chip':
        _drawIC(canvas, pos, component, paint, fillPaint);
        break;
      case 'inductor':
        _drawInductor(canvas, pos, paint, fillPaint);
        break;
      case 'diode':
        _drawDiode(canvas, pos, paint, fillPaint);
        break;
      case 'transistor':
        _drawTransistor(canvas, pos, paint, fillPaint);
        break;
      default:
        _drawGenericComponent(canvas, pos, paint, fillPaint);
    }

    // Draw component label
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${component.id}\n${component.value ?? ""}',
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white70,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(canvas, pos + Offset(-textPainter.width / 2, 20));

    // Draw pins
    final pinPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    for (final pin in component.pins.values) {
      final pinPos = Offset(pin.position.x, pin.position.y);
      canvas.drawCircle(pinPos, 2, pinPaint);

      // Draw pin labels if component is selected
      if (isSelected && pin.function != null) {
        final pinTextPainter = TextPainter(
          text: TextSpan(
            text: pin.function,
            style: TextStyle(color: Colors.orange, fontSize: 8),
          ),
          textDirection: TextDirection.ltr,
        );
        pinTextPainter.layout();
        pinTextPainter.paint(canvas, pinPos + Offset(3, -10));
      }
    }
  }

  void _drawResistor(
    ui.Canvas canvas,
    Offset pos,
    Paint paint,
    Paint fillPaint,
  ) {
    final rect = Rect.fromCenter(center: pos, width: 20, height: 8);
    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, paint);
    canvas.drawLine(pos + Offset(-20, 0), pos + Offset(-10, 0), paint);
    canvas.drawLine(pos + Offset(20, 0), pos + Offset(10, 0), paint);
  }

  void _drawCapacitor(
    ui.Canvas canvas,
    Offset pos,
    Paint paint,
    Paint fillPaint,
  ) {
    canvas.drawLine(pos + Offset(-4, -10), pos + Offset(-4, 10), paint);
    canvas.drawLine(pos + Offset(4, -10), pos + Offset(4, 10), paint);
    canvas.drawLine(pos + Offset(-20, 0), pos + Offset(-4, 0), paint);
    canvas.drawLine(pos + Offset(20, 0), pos + Offset(4, 0), paint);
  }

  void _drawIC(
    ui.Canvas canvas,
    Offset pos,
    Component component,
    Paint paint,
    Paint fillPaint,
  ) {
    final pinCount = component.pins.length;
    final width = 40.0;
    final height = math.max(20.0, pinCount * 5.0);

    final rect = Rect.fromCenter(center: pos, width: width, height: height);
    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, paint);

    // Draw notch
    canvas.drawCircle(pos + Offset(-width / 2, 0), 3, paint);
  }

  void _drawInductor(
    ui.Canvas canvas,
    Offset pos,
    Paint paint,
    Paint fillPaint,
  ) {
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

  void _drawDiode(ui.Canvas canvas, Offset pos, Paint paint, Paint fillPaint) {
    final path = Path();
    path.moveTo(pos.dx - 10, pos.dy - 8);
    path.lineTo(pos.dx + 10, pos.dy);
    path.lineTo(pos.dx - 10, pos.dy + 8);
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
    canvas.drawLine(pos + Offset(10, -8), pos + Offset(10, 8), paint);
  }

  void _drawTransistor(
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

  void _drawGenericComponent(
    ui.Canvas canvas,
    Offset pos,
    Paint paint,
    Paint fillPaint,
  ) {
    final rect = Rect.fromCenter(center: pos, width: 30, height: 20);
    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant SchematicPainter oldDelegate) {
    return oldDelegate.selectedComponent != selectedComponent ||
        oldDelegate.selectedNet != selectedNet ||
        oldDelegate.showComponents != showComponents ||
        oldDelegate.showNets != showNets;
  }
}
