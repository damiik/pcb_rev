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

    // Apply transformations for the symbol graphics
    final position = Offset(symbolInstance.at.x, symbolInstance.at.y);
    final rotation = symbolInstance.at.angle;
    final mirrorX = symbolInstance.mirrorx;
    final mirrorY = symbolInstance.mirrory;

    canvas.translate(position.dx, position.dy);

    // Apply mirroring first, then rotation
    // Mirroring should be applied before rotation for correct transformation
    final mx = mirrorY ? -1.0 : 1.0;
    final my = mirrorX ? -1.0 : 1.0;
    canvas.scale(mx, my);

    // KiCad uses inverted Y axis for symbols, so we apply this locally.
    if (rotation != 0) {
      canvas.rotate(-rotation * math.pi / 180);
    }
    canvas.scale(1, -1);

    // Draw symbol units (mirroring is now applied at canvas level)
    for (final unit in symbol.units) {
      _drawSymbolUnit(
        canvas,
        unit,
        paint,
        fillPaint,
        isSelected,
        !symbol.hidePinNumbers,
        mirrorX,
        mirrorY,
      );
    }
    // Restore canvas state to draw text properties in the correct space
    canvas.restore();

    // --- Draw Pin Text ---
    // Pin text is drawn with position transformations but without canvas rotation to keep text readable
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.scale(1, -1); // KiCad Y-axis inversion

    for (final unit in symbol.units) {
      for (final pin in unit.pins) {
        _drawPinText(
          canvas,
          pin,
          paint,
          !symbol.hidePinNumbers,
          mirrorX,
          mirrorY,
          mirrorY ? -1.0 : 1.0,
          mirrorX ? -1.0 : 1.0,
          rotation,
        );
      }
    }
    canvas.restore();

    // --- Draw Text Properties (Reference, Value) ---
    // Text is drawn outside the symbol's scaled/rotated canvas to avoid distortion.
    canvas.save();
    // canvas.translate(position.dx, position.dy);
    // if (rotation != 0) {
    //   canvas.rotate(-rotation * math.pi / 180);
    // }
    // We don't use canvas.scale(1, -1) here, so Y is downwards.
    _drawComponentInfo(canvas, symbolInstance, paint, mirrorX, mirrorY);
    canvas.restore();
  }

  /// Draw a symbol unit (graphics and pins)
  void _drawSymbolUnit(
    ui.Canvas canvas,
    SymbolUnit unit,
    Paint paint,
    Paint fillPaint,
    bool isSelected,
    bool showPinNumbers,
    bool mirrorX,
    bool mirrorY,
  ) {
    // Mirroring is now applied at canvas level, so we use identity factors here
    final mx = 1.0;
    final my = 1.0;

    // Draw graphics (rectangles, etc.)
    for (final graphic in unit.graphics) {
      switch (graphic.runtimeType) {
        case Rectangle:
          _drawRectangle(
            canvas,
            graphic as Rectangle,
            paint,
            fillPaint,
            isSelected,
            mx,
            my,
          );
          break;

        case Circle:
          final circle = graphic as Circle;
          final center = Offset(circle.center.x * mx, circle.center.y * my);
          canvas.drawCircle(center, circle.radius, paint);
          if (circle.fill.type != FillType.none) {
            canvas.drawCircle(center, circle.radius, fillPaint);
          }
          break;

        case Polyline:
          final polyline = graphic as Polyline;
          final path = ui.Path();
          if (polyline.points.isNotEmpty) {
            final firstPoint = polyline.points.first;
            path.moveTo(firstPoint.x * mx, firstPoint.y * my);
            for (final point in polyline.points.skip(1)) {
              path.lineTo(point.x * mx, point.y * my);
            }
          }
          canvas.drawPath(path, paint);
          if (polyline.fill.type != FillType.none) {
            canvas.drawPath(path, fillPaint);
          }
          break;
      }
    }

    // Draw pins
    for (final pin in unit.pins) {
      _drawPin(canvas, pin, paint, showPinNumbers, mirrorX, mirrorY, mx, my);
    }
  }

  /// Draw a rectangle graphic element, applying mirroring.
  void _drawRectangle(
    ui.Canvas canvas,
    Rectangle rectangle,
    Paint paint,
    Paint fillPaint,
    bool isSelected,
    double mx,
    double my,
  ) {
    // Ensure start is top-left and end is bottom-right after mirroring
    final x1 = rectangle.start.x * mx;
    final y1 = rectangle.start.y * my;
    final x2 = rectangle.end.x * mx;
    final y2 = rectangle.end.y * my;

    final rect = Rect.fromLTRB(
      math.min(x1, x2),
      math.min(y1, y2),
      math.max(x1, x2),
      math.max(y1, y2),
    );

    Paint rectPaint = isSelected ? (paint..color = Colors.blue) : paint;
    Paint rectFillPaint = isSelected
        ? (fillPaint..color = Colors.blue.withOpacity(0.3))
        : fillPaint;

    if (rectangle.fill.type == FillType.background) {
      canvas.drawRect(rect, rectFillPaint);
    }
    canvas.drawRect(rect, rectPaint);
  }

  /// Draw a pin, applying mirroring.
  void _drawPin(
    ui.Canvas canvas,
    Pin pin,
    Paint paint,
    bool showPinNumbers,
    bool mirrorX,
    bool mirrorY,
    double mx,
    double my,
  ) {
    final angle = pin.angle * (math.pi / 180);
    final startPos = Offset(pin.position.x * mx, pin.position.y * my);

    // To correctly mirror the pin, we calculate its original end point
    // and then mirror those coordinates.
    final endPosOriginal = Offset(
      pin.position.x + pin.length * math.cos(angle),
      pin.position.y + pin.length * math.sin(angle),
    );
    final endPos = Offset(endPosOriginal.dx * mx, endPosOriginal.dy * my);

    canvas.drawLine(startPos, endPos, paint);

    // Pin text will be drawn separately outside canvas transformations to avoid mirroring
  }

  /// Draw pin number and name text.
  /// Text position is mirrored, but the text itself is not, to maintain readability.
  void _drawPinText(
    ui.Canvas canvas,
    Pin pin,
    Paint paint,
    bool showPinNumbers,
    bool mirrorX,
    bool mirrorY,
    double mx,
    double my,
    double rotation,
  ) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // --- Draw Pin Number ---
    if (showPinNumbers && pin.number.isNotEmpty) {
      textPainter.text = TextSpan(
        text: pin.number,
        style: TextStyle(
          color: Colors.white70,
          fontSize: pin.numberEffects.font.height,
        ),
      );
      textPainter.layout();

      // Position pin number based on pin angle
      var numberOffset = Offset.zero;
      var nameOffset = Offset.zero;
      var angleRad = 0.0;
      var distance = 0.2; // Distance from pin end

      if (showPinNumbers) {
        // Calculate effective pin angle including symbol rotation
        final effectivePinAngle = (pin.angle + rotation) % 360;

        if (effectivePinAngle >= 315 || effectivePinAngle < 45) {
          // Left side
          numberOffset = Offset(pin.position.x, pin.position.y + 0.2);
        } else if (effectivePinAngle >= 45 && effectivePinAngle < 135) {
          // Bottom side
          numberOffset = Offset(pin.position.x - 0.2, pin.position.y);
          angleRad = 90.0 * math.pi / 180.0;
        } else if (effectivePinAngle >= 135 && effectivePinAngle < 225) {
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

        // Apply symbol rotation to pin text position
        if (rotation != 0) {
          final rotRad = rotation * math.pi / 180;
          final cosR = math.cos(rotRad);
          final sinR = math.sin(rotRad);
          final rotX = numberOffset.dx * cosR - numberOffset.dy * sinR;
          final rotY = numberOffset.dx * sinR - numberOffset.dy * cosR;
          numberOffset = Offset(rotX, rotY);
        }

        canvas.save();
        canvas.translate(
          numberOffset.dx * (mirrorY ? -1 : 1),
          numberOffset.dy * (mirrorX ? -1 : 1),
        );
        canvas.rotate(angleRad);
        canvas.scale(
          1,
          -1,
        ); // KiCad uses inverted Y axis in symbol definition (Y values grow upwards)
        textPainter.paint(canvas, Offset(0, -textPainter.height));
        canvas.restore();
      }

      // --- Draw Pin Name ---
      if (pin.name.isNotEmpty && pin.name != '~') {
        textPainter.text = TextSpan(
          text: pin.name,
          style: TextStyle(
            color: Colors.yellow,
            fontSize: pin.nameEffects.font.height,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        if (!showPinNumbers) distance = -1.5;

        // Calculate effective pin angle including symbol rotation for pin name
        final effectivePinAngle = (pin.angle + rotation) % 360;

        if (effectivePinAngle >= 315 || effectivePinAngle < 45) {
          // Left side
          nameOffset = Offset(
            pin.position.x + pin.length + distance,
            pin.position.y - textPainter.height,
          );
        } else if (effectivePinAngle >= 45 && effectivePinAngle < 135) {
          // Bottom side
          nameOffset = Offset(
            pin.position.x + textPainter.height,
            pin.position.y + pin.length + distance,
          );
          angleRad = 90.0 * math.pi / 180.0;
        } else if (effectivePinAngle >= 135 && effectivePinAngle < 225) {
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

        // Apply symbol rotation to pin name position
        if (rotation != 0) {
          final rotRad = rotation * math.pi / 180;
          final cosR = math.cos(rotRad);
          final sinR = math.sin(rotRad);
          final rotX = nameOffset.dx * cosR - nameOffset.dy * sinR;
          final rotY = nameOffset.dx * sinR + nameOffset.dy * cosR;
          nameOffset = Offset(rotX, rotY);
        }

        canvas.save();
        canvas.translate(
          nameOffset.dx * (mirrorY ? -1 : 1),
          nameOffset.dy * (mirrorX ? -1 : 1),
        );
        canvas.rotate(angleRad);
        canvas.scale(
          1,
          -1,
        ); // KiCad uses inverted Y axis in symbol definition (Y values grow upwards)
        textPainter.paint(canvas, Offset(0, -textPainter.height));
        canvas.restore();
      }
    }
  }

  Offset _calculatePinNumberOffset(Pin pin, Size textSize) {
    final pos = pin.position;
    final angle = pin.angle * (math.pi / 180);
    // Position inside the symbol body, near the pin root
    final distance = (pin.numberEffects.font.height / 2) + 0.25;
    final dx =
        pos.x +
        distance * math.cos(angle + math.pi); // Move opposite to pin direction
    final dy = pos.y + distance * math.sin(angle + math.pi);
    return Offset(dx, dy);
  }

  Offset _calculatePinNameOffset(Pin pin, Size textSize) {
    final pos = pin.position;
    final angle = pin.angle * (math.pi / 180);
    final length = pin.length;
    // Position outside the symbol body, near the pin tip
    final distance = length + (pin.nameEffects.font.height / 2) + 0.25;
    final dx = pos.x + distance * math.cos(angle);
    final dy = pos.y + distance * math.sin(angle);
    return Offset(dx, dy);
  }

  /// Draw component ID and value.
  /// This is drawn in a separate canvas context, so transformations are simpler.
  void _drawComponentInfo(
    ui.Canvas canvas,
    SymbolInstance symbol,
    Paint paint,
    bool mirrorX,
    bool mirrorY,
  ) {
    for (final property in symbol.properties) {
      if ((property.name != 'Value' && property.name != 'Reference') ||
          property.value.isEmpty ||
          property.hidden) {
        continue;
      }

      final effects = property.effects;
      final propertyPainter = TextPainter(
        text: TextSpan(
          text: property.value,
          style: TextStyle(
            color: Colors.white70,
            fontSize: effects.font.height,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      );
      propertyPainter.layout();

      // Mirror the text's position, but not the text itself.
      // The Y coordinate is negated because this canvas context has Y pointing down,
      // opposite to the symbol's internal coordinate system.
      var x = property.position.x;
      var y = property.position.y;

      // if (mirrorY) x = -x; // Mirror around Y-axis affects X coord
      // if (mirrorX) y = -y; // Mirror around X-axis affects Y coord
      propertyPainter.paint(canvas, Offset(x, y));

      //   final angle = -property.position.angle; // KiCad angle is opposite

      //   canvas.save();
      //   canvas.translate(x, y);
      //   if (angle != 0) {
      //     canvas.rotate(angle * math.pi / 180);
      //   }

      //   final justificationOffset = _getJustificationOffset(
      //     propertyPainter.size,
      //     effects.justify,
      //   );
      //   propertyPainter.paint(canvas, justificationOffset);
      //   canvas.restore();

      //   final angle = -property.position.angle; // KiCad angle is opposite

      //   canvas.save();
      //   canvas.translate(x, y);
      //   if (angle != 0) {
      //     canvas.rotate(angle * math.pi / 180);
      //   }

      //   final justificationOffset = _getJustificationOffset(
      //     propertyPainter.size,
      //     effects.justify,
      //   );
      //   propertyPainter.paint(canvas, justificationOffset);
      //   canvas.restore();
    }
  }

  TextAlign _getFlutterTextAlign(Justify justify) {
    if (justify.toString().contains('left')) return TextAlign.left;
    if (justify.toString().contains('right')) return TextAlign.right;
    return TextAlign.center;
  }

  Offset _getJustificationOffset(Size size, Justify justify) {
    double dx = 0;
    double dy = 0;

    // Horizontal alignment
    if (justify.toString().contains('left')) {
      dx = 0;
    } else if (justify.toString().contains('right')) {
      dx = -size.width;
    } else {
      // Center
      dx = -size.width / 2;
    }

    // Vertical alignment
    if (justify.toString().contains('top')) {
      dy = 0;
    } else if (justify.toString().contains('bottom')) {
      dy = -size.height;
    } else {
      // Middle
      dy = -size.height / 2;
    }
    return Offset(dx, dy);
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
