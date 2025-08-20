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

      final ref = symbolInstance.properties
          .firstWhere(
            (p) => p.name == 'Reference',
            orElse: () => Property(
              name: 'Reference',
              value: '',
              id: 0,
              position: Position(0, 0),
              effects: TextEffects(
                font: Font(width: 0, height: 0),
                justify: Justify.left,
              ),
            ),
          )
          .value;
      final value = symbolInstance.properties
          .firstWhere(
            (p) => p.name == 'Value',
            orElse: () => Property(
              name: 'Value',
              value: '',
              id: 0,
              position: Position(0, 0),
              effects: TextEffects(
                font: Font(width: 0, height: 0),
                justify: Justify.left,
              ),
            ),
          )
          .value;

      symbolRenderer.renderSymbol(
        canvas,
        symbol,
        symbolInstance,
        paint,
        fillPaint,
      );
    }
  }
}
