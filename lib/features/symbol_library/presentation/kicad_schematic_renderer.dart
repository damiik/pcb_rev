import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_models.dart';
import 'kicad_symbol_renderer.dart';

const double kicadUnitToPx = 2.5; // albo dynamicznie dobrane
const double kicadStrokeWidth = 0.2;
const double kicadJunctionSize = 0.5;
const ui.Color kicadWireColor = ui.Color(0xFF87BB4C);
const ui.Color kicadSymbolColor = ui.Color(0xFFE08A62);
const ui.Color kicadLabelColor = ui.Color(0xFF4C96BB);

/// Renderer for a full KiCad schematic.
class KiCadSchematicRenderer {
  final Map<String, Symbol> _symbolCache;

  KiCadSchematicRenderer(this._symbolCache);

  /// Renders the entire schematic onto a canvas.
  void render(ui.Canvas canvas, ui.Size size, KiCadSchematic schematic) {
    // Create a renderer on-the-fly for the schematic's embedded library
    final symbolRenderer = KiCadSymbolRenderer();

    // TODO: Add zoom and pan transformation

    canvas.scale(kicadUnitToPx);

    _drawWires(canvas, schematic.wires);
    _drawJunctions(canvas, schematic.junctions);
    _drawSymbols(canvas, schematic.symbols, symbolRenderer);
    _drawGlobalLabels(canvas, schematic.globalLabels);
  }

  void _drawWires(ui.Canvas canvas, List<Wire> wires) {
    final paint = Paint()
      ..color = kicadWireColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = kicadStrokeWidth * 0.5; // Adjusted for better visibility

    for (final wire in wires) {
      if (wire.pts.length < 2) continue;
      final path = Path();
      path.moveTo(wire.pts.first.x, wire.pts.first.y);
      for (var i = 1; i < wire.pts.length; i++) {
        path.lineTo(wire.pts[i].x, wire.pts[i].y);
      }
      canvas.drawPath(
        path,
        paint
          ..strokeWidth = wire.stroke.width > 0
              ? wire.stroke.width
              : kicadStrokeWidth,
      );
    }
  }

  void _drawJunctions(ui.Canvas canvas, List<Junction> junctions) {
    final paint = Paint()
      ..color = kicadWireColor
      ..style = PaintingStyle.fill;

    for (final junction in junctions) {
      canvas.drawCircle(
        Offset(junction.at.x, junction.at.y),
        kicadJunctionSize,
        paint,
      );
    }
  }

  void _drawSymbols(
    ui.Canvas canvas,
    List<SymbolInstance> symbols,
    KiCadSymbolRenderer symbolRenderer,
  ) {
    final paint = Paint()
      ..color = kicadSymbolColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = kicadStrokeWidth;

    final fillPaint = Paint()
      ..color = kicadSymbolColor
      ..style = PaintingStyle.fill;

    for (final symbolInstance in symbols) {
      final symbol = _symbolCache[symbolInstance.libId];
      if (symbol == null) {
        print('Symbol not found in cache: ${symbolInstance.libId}');
        continue;
      }

      symbolRenderer.renderSymbol(
        canvas,
        symbol,
        symbolInstance,
        paint,
        fillPaint,
      );
    }
  }

  void _drawGlobalLabels(ui.Canvas canvas, List<GlobalLabel> labels) {
    for (final label in labels) {
      if (label.effects.hide) continue;

      final textPainter = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            color: kicadLabelColor,
            fontSize: label.effects.font.height,
            fontWeight: FontWeight.normal,
            fontStyle: FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final spacing = 0.5; // Small spacing from the label shape

      canvas.save();
      canvas.translate(label.at.x, label.at.y);

      // TODO: Adjust text position based on label shape and rotation
      textPainter.paint(
        canvas,
        Offset(
          label.effects.justify == Justify.right
              ? -textPainter.width - spacing
              : spacing,
          -label.effects.font.height / 2,
        ),
      );
      canvas.rotate(
        -label.at.angle * (3.14159 / 180),
      ); // KiCad rotation is in degrees

      _drawLabelShape(canvas, label, textPainter.width + spacing * 2);

      canvas.restore();
    }
  }

  void _drawLabelShape(ui.Canvas canvas, GlobalLabel label, double length) {
    final paint = Paint()
      ..color = kicadLabelColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.10;

    final path = Path();
    const len = 2.54; // Standard length for the label tail

    // The shape is drawn relative to the label's anchor point (0,0)
    switch (label.shape) {
      case LabelShape.input:
        path.moveTo(length, len * 0.3);
        path.lineTo(length, -len * 0.3);
        path.lineTo(0.4, -len * 0.3);
        path.lineTo(0, 0);
        path.lineTo(0.4, len * 0.3);
        path.lineTo(length, len * 0.3);

        break;
      case LabelShape.output:
        path.moveTo(0, len * 0.3);
        path.lineTo(0, -len * 0.3);
        path.lineTo(length, -len * 0.3);
        path.lineTo(length + 0.4, 0);
        path.lineTo(length, len * 0.3);
        path.lineTo(0, len * 0.3);
        break;
      case LabelShape.bidirectional: // TODO
        path.moveTo(0, 0);
        path.lineTo(len, 0);
        path.moveTo(len * 0.3, -len * 0.4);
        path.lineTo(0, 0);
        path.lineTo(len * 0.3, len * 0.4);
        path.moveTo(len * 0.7, -len * 0.4);
        path.lineTo(len, 0);
        path.lineTo(len * 0.7, len * 0.4);
        break;
      default: // passive and others
        path.moveTo(0, 0);
        path.lineTo(len, 0);
        break;
    }

    canvas.drawPath(path, paint);
  }
}
