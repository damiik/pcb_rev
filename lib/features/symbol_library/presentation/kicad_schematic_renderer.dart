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
const ui.Color kicadHighlightColor = Colors.yellow;

double calcSafeAngleRad(double angle) => angle >= 90 && angle < 180
    ? -90 * (3.14159 / 180)
    : angle >= 180 && angle < 270
        ? 0
        : angle >= 270 && angle < 360
            ? -90 * (3.14159 / 180)
            : 0;

/// Renderer for a full KiCad schematic.
class KiCadSchematicRenderer {
  final Map<String, Symbol> _symbolCache;
  final String? selectedSymbolId;

  KiCadSchematicRenderer(this._symbolCache, {this.selectedSymbolId});

  /// Renders the entire schematic onto a canvas.
  void render(ui.Canvas canvas, ui.Size size, KiCadSchematic schematic) {
    // Create a renderer on-the-fly for the schematic's embedded library
    final symbolRenderer = KiCadSymbolRenderer();

    // TODO: Add zoom and pan transformation

    canvas.scale(kicadUnitToPx);

    _drawWires(canvas, schematic.wires);
    _drawBuses(canvas, schematic.buses);
    _drawBusEntries(canvas, schematic.busEntries);
    _drawJunctions(canvas, schematic.junctions);
    _drawSymbols(canvas, schematic.symbols, symbolRenderer);
    _drawGlobalLabels(canvas, schematic.globalLabels);
    _drawLabels(canvas, schematic.labels);
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
          ..strokeWidth =
              wire.stroke.width > 0 ? wire.stroke.width : kicadStrokeWidth,
      );
    }
  }

  void _drawBuses(ui.Canvas canvas, List<Bus> buses) {
    final paint = Paint()
      ..color = kicadWireColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = kicadStrokeWidth * 3; // Thicker for buses

    for (final bus in buses) {
      if (bus.pts.length < 2) continue;
      final path = Path();
      path.moveTo(bus.pts.first.x, bus.pts.first.y);
      for (var i = 1; i < bus.pts.length; i++) {
        path.lineTo(bus.pts[i].x, bus.pts[i].y);
      }
      canvas.drawPath(
        path,
        paint
          ..strokeWidth = 
              bus.stroke.width > 0 ? bus.stroke.width : kicadStrokeWidth * 3,
      );
    }
  }

  void _drawBusEntries(ui.Canvas canvas, List<BusEntry> busEntries) {
    final paint = Paint()
      ..color = kicadWireColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = kicadStrokeWidth;

    for (final entry in busEntries) {
      final path = Path();
      path.moveTo(entry.at.x, entry.at.y);
      path.lineTo(
        entry.at.x + entry.size.width,
        entry.at.y + entry.size.height,
      );
      canvas.drawPath(
        path,
        paint
          ..strokeWidth = 
              entry.stroke.width > 0 ? entry.stroke.width : kicadStrokeWidth,
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

    final highlightPaint = Paint()
      ..color = kicadHighlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = kicadStrokeWidth * 1.5;

    final highlightFillPaint = Paint()
      ..color = kicadHighlightColor.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (final symbolInstance in symbols) {
      final symbol = _symbolCache[symbolInstance.libId];
      if (symbol == null) {
        print('Symbol not found in cache: ${symbolInstance.libId}');
        continue;
      }

      final bool isSelected = symbolInstance.uuid == selectedSymbolId;

      symbolRenderer.renderSymbol(
        canvas,
        symbol,
        symbolInstance,
        isSelected ? highlightPaint : paint,
        isSelected ? highlightFillPaint : fillPaint,
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

      final angle = label.at.angle >= 90 && label.at.angle < 180
          ? -90
          : label.at.angle >= 180 && label.at.angle < 270
              ? 0
              : label.at.angle >= 270 && label.at.angle < 360
                  ? -90
                  : 0;

      canvas.save();
      canvas.translate(label.at.x, label.at.y);
      canvas.save();
      canvas.rotate(angle * (3.14159 / 180)); // KiCad rotation is in degrees

      textPainter.paint(
        canvas,
        Offset(
          label.effects.justify == Justify.right
              ? -textPainter.width - spacing
              : spacing,
          -label.effects.font.height / 2,
        ),
      );
      canvas.restore();
      canvas.rotate(-label.at.angle * (3.14159 / 180));

      _drawLabelShape(canvas, label, textPainter.width + spacing * 2);

      canvas.restore();
    }
  }

  void _drawLabels(ui.Canvas canvas, List<Label> labels) {
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
      // final angle = label.at.angle >= 90 && label.at.angle < 180
      //     ? -90
      //     : label.at.angle >= 180 && label.at.angle < 270
      //     ? 0
      //     : label.at.angle >= 270 && label.at.angle < 360
      //     ? -90
      //     : 0;

      canvas.save();
      canvas.translate(label.at.x, label.at.y);
      // canvas.rotate(angle * (3.14159 / 180)); // KiCad rotation is in degrees
      canvas.rotate(calcSafeAngleRad(label.at.angle));
      final offset = switch (label.effects.justify) {
        Justify.left => Offset(0, spacing),
        Justify.center => Offset(-textPainter.width / 2, spacing),
        Justify.right => Offset(-textPainter.width, spacing),
        Justify.top => Offset(0, spacing),
        Justify.bottom => Offset(0, -textPainter.height - spacing),
        Justify.topLeft => Offset(0, 0),
        Justify.topRight => Offset(-textPainter.width, spacing),
        Justify.bottomLeft => Offset(0, -textPainter.height - spacing),
        Justify.bottomRight => Offset(
          -textPainter.width,
          -textPainter.height - spacing,
        ),
      };

      textPainter.paint(canvas, offset);

      canvas.restore();
    }
  }

  void _drawLabelShape(ui.Canvas canvas, GlobalLabel label, double length) {
    final paint = Paint()
      ..color = const ui.Color(0xFFBA63BD)
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

      case LabelShape.bidirectional:
        path.moveTo(0.4, len * 0.3);
        path.lineTo(0, 0);
        path.lineTo(0.4, -len * 0.3);
        path.lineTo(length, -len * 0.3);
        path.lineTo(length + 0.4, 0);
        path.lineTo(length, len * 0.3);
        path.lineTo(0.4, len * 0.3);
        break;

      default: // passive and others
        path.moveTo(0, 0);
        path.lineTo(len, 0);
        break;
    }

    canvas.drawPath(path, paint);
  }
}
