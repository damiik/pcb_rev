import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pcb_rev/models/project.dart';
import '../../models/logical_models.dart';
import 'component_painters.dart';

class GridPainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 0.5;
    const gridSize = 20.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SchematicPainter extends CustomPainter {
  final Project project;
  final LogicalComponent? draggingComponent;
  final Offset? mousePosition;

  SchematicPainter({
    required this.project,
    this.draggingComponent,
    this.mousePosition,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    _drawComponents(canvas);
    if (draggingComponent != null && mousePosition != null) {
      _drawComponent(
        canvas,
        draggingComponent!,
        mousePosition!,
        isDragging: true,
      );
    }
  }

  void _drawComponents(ui.Canvas canvas) {
    for (final symbol in project.schematic.symbols.values) {
      final component = project.logicalComponents[symbol.logicalComponentId];
      if (component != null) {
        _drawComponent(
          canvas,
          component,
          Offset(symbol.position.x, symbol.position.y),
        );
      }
    }
  }

  void _drawComponent(
    ui.Canvas canvas,
    LogicalComponent component,
    Offset pos, {
    bool isDragging = false,
  }) {
    final paint = Paint()
      ..color = isDragging ? Colors.blue.withOpacity(0.5) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final fillPaint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.fill;

    drawComponentSymbol(canvas, component, pos, paint, fillPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${component.id}\n${component.value ?? ""}',
        style: TextStyle(color: Colors.white70, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(canvas, pos + Offset(-textPainter.width / 2, 20));
  }

  @override
  bool shouldRepaint(covariant SchematicPainter oldDelegate) => true;
}
