import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../data/kicad_symbol_models.dart';
import '../data/kicad_symbol_loader.dart';

/// Renderer for KiCad symbols on canvas
class KiCadSymbolRenderer {
  final KiCadSymbolLoader _loader;

  KiCadSymbolRenderer(this._loader);

  /// Render a KiCad symbol on the canvas
  Future<void> renderSymbol(
    ui.Canvas canvas,
    String symbolName,
    Offset position,
    Paint paint,
    Paint fillPaint, {
    bool isSelected = false,
    double rotation = 0,
    String? componentId,
    String? componentValue,
  }) async {
    final symbol = await _loader.loadSymbol(symbolName);

    // Save canvas state
    canvas.save();

    // Apply transformations
    canvas.translate(position.dx, position.dy);
    if (rotation != 0) {
      canvas.rotate(rotation);
    }
    canvas.translate(-position.dx, -position.dy);

    // Draw symbol units
    for (final unit in symbol.units) {
      _drawSymbolUnit(canvas, unit, position, paint, fillPaint, isSelected);
    }

    // Draw component info
    if (componentId != null || componentValue != null) {
      _drawComponentInfo(
        canvas,
        symbol,
        position,
        componentId,
        componentValue,
        paint,
      );
    }

    // Restore canvas state
    canvas.restore();
  }

  /// Draw a symbol unit (graphics and pins)
  void _drawSymbolUnit(
    ui.Canvas canvas,
    SymbolUnit unit,
    Offset position,
    Paint paint,
    Paint fillPaint,
    bool isSelected,
  ) {
    // Draw graphics (rectangles, etc.)
    for (final graphic in unit.graphics) {
      if (graphic is Rectangle) {
        _drawRectangle(canvas, graphic, paint, fillPaint, isSelected);
      }
      // Add other graphic types as needed
    }

    // Draw pins
    for (final pin in unit.pins) {
      _drawPin(canvas, pin, paint);
    }
  }

  /// Draw a rectangle graphic element
  void _drawRectangle(
    ui.Canvas canvas,
    Rectangle rectangle,
    Paint paint,
    Paint fillPaint,
    bool isSelected,
  ) {
    final rect = Rect.fromPoints(
      Offset(rectangle.start.x, rectangle.start.y),
      Offset(rectangle.end.x, rectangle.end.y),
    );

    // Update colors based on selection
    Paint rectPaint;
    Paint rectFillPaint;
    if (isSelected) {
      rectPaint = paint..color = Colors.blue;
      rectFillPaint = fillPaint..color = Colors.blue.withOpacity(0.3);
    } else {
      rectPaint = paint;
      rectFillPaint = fillPaint;
    }

    // Draw filled rectangle if specified
    if (rectangle.fill.type != FillType.none) {
      if (rectangle.fill.type == FillType.background) {
        canvas.drawRect(rect, rectFillPaint);
      }
    }

    // Draw stroke
    canvas.drawRect(rect, rectPaint);
  }

  /// Draw a pin
  void _drawPin(ui.Canvas canvas, Pin pin, Paint paint) {
    final startPos = Offset(pin.position.x, pin.position.y);
    final endPos = Offset(
      pin.position.x + pin.length * math.cos(pin.angle * math.pi / 180),
      pin.position.y + pin.length * math.sin(pin.angle * math.pi / 180),
    );

    // Draw pin line
    canvas.drawLine(startPos, endPos, paint);

    // Draw pin number and name
    _drawPinText(canvas, pin, paint);
  }

  /// Draw pin number and name text
  void _drawPinText(ui.Canvas canvas, Pin pin, Paint paint) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw pin number
    textPainter.text = TextSpan(
      text: pin.number,
      style: TextStyle(color: Colors.white70, fontSize: 8),
    );
    textPainter.layout();

    // Position pin number based on pin angle
    Offset numberOffset;
    final angleRad = pin.angle * math.pi / 180;
    final distance = 3.0; // Distance from pin end

    if (pin.angle >= 315 || pin.angle < 45) {
      // Right side
      numberOffset = Offset(
        pin.position.x + pin.length + distance,
        pin.position.y - textPainter.height / 2,
      );
    } else if (pin.angle >= 45 && pin.angle < 135) {
      // Bottom side
      numberOffset = Offset(
        pin.position.x - textPainter.width / 2,
        pin.position.y + pin.length + distance,
      );
    } else if (pin.angle >= 135 && pin.angle < 225) {
      // Left side
      numberOffset = Offset(
        pin.position.x - pin.length - textPainter.width - distance,
        pin.position.y - textPainter.height / 2,
      );
    } else {
      // Top side
      numberOffset = Offset(
        pin.position.x - textPainter.width / 2,
        pin.position.y - pin.length - textPainter.height - distance,
      );
    }

    textPainter.paint(canvas, numberOffset);

    // Draw pin name (if different from number)
    if (pin.name != pin.number && pin.name.isNotEmpty) {
      textPainter.text = TextSpan(
        text: pin.name,
        style: TextStyle(color: Colors.yellow, fontSize: 6),
      );
      textPainter.layout();

      // Position pin name slightly offset from number
      final nameOffset = numberOffset + Offset(0, textPainter.height + 1);
      textPainter.paint(canvas, nameOffset);
    }
  }

  /// Draw component ID and value
  void _drawComponentInfo(
    ui.Canvas canvas,
    Symbol symbol,
    Offset position,
    String? componentId,
    String? componentValue,
    Paint paint,
  ) {
    final text = '${componentId ?? ""}\n${componentValue ?? ""}';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.white70, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();

    // Position below the symbol
    // Find the bounding box of all units to determine symbol size
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final unit in symbol.units) {
      for (final graphic in unit.graphics) {
        if (graphic is Rectangle) {
          minX = math.min(minX, graphic.start.x);
          maxX = math.max(maxX, graphic.end.x);
          minY = math.min(minY, graphic.start.y);
          maxY = math.max(maxY, graphic.end.y);
        }
      }
    }

    final symbolHeight = maxY - minY;
    final textOffset =
        position + Offset(-textPainter.width / 2, symbolHeight / 2 + 10);
    textPainter.paint(canvas, textOffset);
  }

  /// Get connection points for a symbol (used for wire routing)
  Future<List<Offset>> getConnectionPoints(
    String symbolName,
    Offset position,
    double rotation,
  ) async {
    final symbol = await _loader.loadSymbol(symbolName);
    final connectionPoints = <Offset>[];

    for (final unit in symbol.units) {
      for (final pin in unit.pins) {
        // Apply rotation to connection point
        var connectionPoint = position + Offset(pin.position.x, pin.position.y);

        if (rotation != 0) {
          final relativePoint = Offset(pin.position.x, pin.position.y);
          final angle = rotation * math.pi / 180;
          final cos = math.cos(angle);
          final sin = math.sin(angle);

          final rotatedX = relativePoint.dx * cos - relativePoint.dy * sin;
          final rotatedY = relativePoint.dx * sin + relativePoint.dy * cos;

          connectionPoint = position + Offset(rotatedX, rotatedY);
        }

        connectionPoints.add(connectionPoint);
      }
    }

    return connectionPoints;
  }

  /// Get the bounding box of a symbol
  Future<Rect> getSymbolBounds(String symbolName) async {
    final symbol = await _loader.loadSymbol(symbolName);

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final unit in symbol.units) {
      for (final graphic in unit.graphics) {
        if (graphic is Rectangle) {
          minX = math.min(minX, graphic.start.x);
          maxX = math.max(maxX, graphic.end.x);
          minY = math.min(minY, graphic.start.y);
          maxY = math.max(maxY, graphic.end.y);
        }
      }

      // Include pins in bounding box
      for (final pin in unit.pins) {
        minX = math.min(minX, pin.position.x);
        maxX = math.max(maxX, pin.position.x);
        minY = math.min(minY, pin.position.y);
        maxY = math.max(maxY, pin.position.y);
      }
    }

    return Rect.fromPoints(Offset(minX, minY), Offset(maxX, maxY));
  }
}
