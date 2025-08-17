import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_loader.dart';
import '../data/kicad_symbol_models.dart';
import 'kicad_symbol_renderer.dart';

/// Renderer for a full KiCad schematic.
class KiCadSchematicRenderer {
  /// Renders the entire schematic onto a canvas.
  Future<void> render(
    ui.Canvas canvas,
    ui.Size size,
    KiCadSchematic schematic,
  ) async {
    if (schematic.library == null) {
      // Or handle this case more gracefully
      print("Warning: Schematic has no embedded symbol library.");
      return;
    }

    // Create a loader and renderer on-the-fly for the schematic's embedded library
    final symbolLoader = KiCadSymbolLoader.fromLibrary(schematic.library!);
    final symbolRenderer = KiCadSymbolRenderer(symbolLoader);

    // TODO: Add zoom and pan transformation

    _drawWires(canvas, schematic.wires);
    _drawJunctions(canvas, schematic.junctions);
    await _drawSymbols(canvas, schematic.symbols, symbolRenderer);
  }

  void _drawWires(ui.Canvas canvas, List<Wire> wires) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 1.0;

    for (final wire in wires) {
      if (wire.pts.length < 2) continue;
      final path = Path();
      path.moveTo(wire.pts.first.x, wire.pts.first.y);
      for (var i = 1; i < wire.pts.length; i++) {
        path.lineTo(wire.pts[i].x, wire.pts[i].y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawJunctions(ui.Canvas canvas, List<Junction> junctions) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;

    for (final junction in junctions) {
      canvas.drawCircle(Offset(junction.at.x, junction.at.y), 2.0, paint);
    }
  }

  Future<void> _drawSymbols(
    ui.Canvas canvas,
    List<SymbolInstance> symbols,
    KiCadSymbolRenderer symbolRenderer,
  ) async {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.fill;

    for (final symbol in symbols) {
      final ref = symbol.properties
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
      final value = symbol.properties
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

      await symbolRenderer.renderSymbol(
        canvas,
        symbol.libId,
        Offset(symbol.at.x, symbol.at.y),
        paint,
        fillPaint,
        rotation: symbol.at.angle,
        componentId: ref,
        componentValue: value,
      );
    }
  }
}
