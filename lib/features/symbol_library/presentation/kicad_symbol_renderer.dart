import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pcb_rev/features/symbol_library/data/kicad_schematic_models.dart';
import 'dart:math' as math;
import '../data/kicad_symbol_models.dart';

/// Renderer for KiCad symbols on canvas
class KiCadSymbolRenderer {
  /// Render a KiCad symbol on the canvas
  void renderSymbol(
    ui.Canvas canvas,
    Symbol symbol,
    SymbolInstance symbolInstance,
    Paint paint,
    Paint fillPaint, {
    bool isSelected = false,
  }) {
    // Save canvas state
    canvas.save();

    // Apply transformations
    final position = Offset(symbolInstance.at.x, symbolInstance.at.y);
    final rotation = symbolInstance.at.angle;

    canvas.translate(position.dx, position.dy);

    // flip osi Y lokalnie dla symbolu
    if (rotation != 0) {
      canvas.rotate(
        -rotation * math.pi / 180,
      ); // KiCad uses inverted Y axis (Y values grow upwards)
    }
    canvas.scale(1, -1);

    // Draw symbol units
    for (final unit in symbol.units) {
      _drawSymbolUnit(
        canvas,
        unit,
        position,
        paint,
        fillPaint,
        isSelected,
        !symbol.hidePinNumbers,
      );
    }
    // Restore canvas state
    canvas.restore();
    // Draw component info

    _drawComponentInfo(canvas, symbolInstance, paint);
  }

  /// Draw a symbol unit (graphics and pins)
  void _drawSymbolUnit(
    ui.Canvas canvas,
    SymbolUnit unit,
    Offset position,
    Paint paint,
    Paint fillPaint,
    bool isSelected,
    bool showPinNumbers,
  ) {
    // Draw graphics (rectangles, etc.)
    for (final graphic in unit.graphics) {
      switch (graphic.runtimeType) {
        case Rectangle:
          // Draw rectangle graphic
          _drawRectangle(
            canvas,
            graphic as Rectangle,
            position,
            paint,
            fillPaint,
            isSelected,
          );
          break;

        case Circle:
          // Draw circle graphic
          final circle = graphic as Circle;
          canvas.drawCircle(
            Offset(circle.center.x, circle.center.y),
            circle.radius,
            paint,
          );
          if (circle.fill.type != FillType.none) {
            canvas.drawCircle(
              Offset(circle.center.x, circle.center.y),
              circle.radius,
              fillPaint,
            );
          }
          break;

        case Polyline:
          final polyline = graphic as Polyline;
          final path = ui.Path();
          if (polyline.points.isNotEmpty) {
            path.moveTo(polyline.points.first.x, polyline.points.first.y);
            for (final point in polyline.points.skip(1)) {
              path.lineTo(point.x, point.y);
            }
          }
          canvas.drawPath(path, paint);
          if (polyline.fill.type != FillType.none) {
            canvas.drawPath(path, fillPaint);
          }
          break;

        // Add other graphic types as needed
      }
    }

    // Draw pins
    for (final pin in unit.pins) {
      _drawPin(canvas, pin, position, paint, showPinNumbers);
    }
  }

  /// Draw a rectangle graphic element
  void _drawRectangle(
    ui.Canvas canvas,
    Rectangle rectangle,
    Offset position,
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
  void _drawPin(
    ui.Canvas canvas,
    Pin pin,
    Offset position,
    Paint paint,
    bool showPinNumbers,
  ) {
    final startPos = Offset(pin.position.x, pin.position.y);
    final endPos = Offset(
      pin.position.x + pin.length * math.cos(pin.angle * math.pi / 180),
      pin.position.y + pin.length * math.sin(pin.angle * math.pi / 180),
    );

    // Draw pin line
    canvas.drawLine(startPos, endPos, paint);

    // Draw pin number and name
    _drawPinText(canvas, pin, position, paint, showPinNumbers);
  }

  /// Draw pin number and name text
  void _drawPinText(
    ui.Canvas canvas,
    Pin pin,
    Offset position,
    Paint paint,
    bool showPinNumbers,
  ) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw pin number
    textPainter.text = TextSpan(
      text: pin.number,
      style: TextStyle(color: Colors.white70, fontSize: 2),
    );
    textPainter.layout();

    // Position pin number based on pin angle
    var numberOffset = Offset.zero;
    var nameOffset = Offset.zero;
    var angleRad = 0.0;
    var distance = 0.2; // Distance from pin end

    if (showPinNumbers) {
      if (pin.angle >= 315 || pin.angle < 45) {
        // Left side
        numberOffset = Offset(pin.position.x, pin.position.y + 0.2);
      } else if (pin.angle >= 45 && pin.angle < 135) {
        // Bottom side
        numberOffset = Offset(pin.position.x - 0.2, pin.position.y);
        angleRad = 90.0 * math.pi / 180.0;
      } else if (pin.angle >= 135 && pin.angle < 225) {
        // Right side
        numberOffset = Offset(
          pin.position.x - pin.length + 0.2,
          pin.position.y + 0.2,
        );
      } else {
        // Top side
        numberOffset = Offset(
          pin.position.x - 0.2,
          pin.position.y - pin.length + 0.2,
        );
        angleRad = 90.0 * math.pi / 180.0;
      }

      canvas.save();
      canvas.translate(numberOffset.dx, numberOffset.dy);
      canvas.rotate(angleRad);
      canvas.scale(
        1,
        -1,
      ); // KiCad uses inverted Y axis in symbol definition (Y values grow upwards)

      textPainter.paint(canvas, Offset(0, -textPainter.height));
      canvas.restore();
    }

    // Draw pin name (if different from number)
    if (pin.name != pin.number && pin.name.isNotEmpty && pin.name != '~') {
      textPainter.text = TextSpan(
        text: pin.name,
        style: TextStyle(
          color: Colors.yellow,
          fontSize: 1.5,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      if (!showPinNumbers) distance = -1.5;

      if (pin.angle >= 315 || pin.angle < 45) {
        // Left side
        nameOffset = Offset(
          pin.position.x + pin.length + distance,
          pin.position.y - textPainter.height,
        );
      } else if (pin.angle >= 45 && pin.angle < 135) {
        // Bottom side
        nameOffset = Offset(
          pin.position.x + textPainter.height,
          pin.position.y + pin.length + distance,
        );
        angleRad = 90.0 * math.pi / 180.0;
      } else if (pin.angle >= 135 && pin.angle < 225) {
        // Right side
        nameOffset = Offset(
          pin.position.x - pin.length - textPainter.width - distance,
          pin.position.y - textPainter.height,
        );
      } else {
        // Top side
        nameOffset = Offset(
          pin.position.x + textPainter.height,
          pin.position.y - pin.length - textPainter.width - distance,
        );
        angleRad = 90.0 * math.pi / 180.0;
      }

      canvas.save();
      canvas.translate(nameOffset.dx, nameOffset.dy);
      canvas.rotate(angleRad);
      canvas.scale(
        1,
        -1,
      ); // KiCad uses inverted Y axis in symbol definition (Y values grow upwards)

      textPainter.paint(canvas, Offset(0, -textPainter.height));
      canvas.restore();
    }
  }

  /// Draw component ID and value
  void _drawComponentInfo(
    ui.Canvas canvas,
    SymbolInstance symbol,

    Paint paint,
  ) {
    for (final property in symbol.properties) {
      if (property.name != 'Value' && property.name != 'Reference') {
        continue; // Skip not Reference and Value properties
      }
      // Draw each property below the symbol
      final propertyPainter = TextPainter(
        text: TextSpan(
          text: property.value,
          style: TextStyle(color: Colors.white70, fontSize: 2),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      );

      propertyPainter.layout();
      propertyPainter.paint(
        canvas,
        Offset(property.position.x, property.position.y),
      );
    }

    // // Position below the symbol
    // // Find the bounding box of all units to determine symbol size
    // double minX = double.infinity, maxX = double.negativeInfinity;
    // double minY = double.infinity, maxY = double.negativeInfinity;

    // for (final unit in symbol.units) {
    //   for (final graphic in unit.graphics) {
    //     if (graphic is Rectangle) {
    //       minX = math.min(minX, graphic.start.x);
    //       maxX = math.max(maxX, graphic.end.x);
    //       minY = math.min(minY, graphic.start.y);
    //       maxY = math.max(maxY, graphic.end.y);
    //     }
    //   }
    // }

    // final symbolHeight = maxY - minY;
    // final textOffset = Offset(-textPainter.width / 2, symbolHeight / 2 + 10);
    // textPainter.paint(canvas, textOffset);
  }

  /// Get connection points for a symbol (used for wire routing)
  List<Offset> getConnectionPoints(
    Symbol symbol,
    Offset position,
    double rotation,
  ) {
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
  Rect getSymbolBounds(Symbol symbol) {
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
