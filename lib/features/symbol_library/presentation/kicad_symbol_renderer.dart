import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pcb_rev/features/symbol_library/data/kicad_schematic_models.dart';
import 'dart:math' as math;
import '../data/kicad_symbol_models.dart';

double calcSafeAngleRad(double angle) => angle >= 90 && angle < 180
    ? -90 * (3.14159 / 180)
    : angle >= 180 && angle < 270
    ? 0
    : angle >= 270 && angle < 360
    ? -90 * (3.14159 / 180)
    : 0;

/// Renderer for KiCad symbols on canvas
class KiCadSymbolRenderer {
  /// Render a KiCad symbol on the canvas
  void renderSymbol(
    ui.Canvas canvas,
    LibrarySymbol symbol,
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
    // KiCad mirror x mirrors around X-axis (changes y coords), mirror y around Y-axis (changes x coords)
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
          mx,
          my,
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
    //   canvas.rotate(calcSafeAngleRad(rotation));
    // }
    // We don't use canvas.scale(1, -1) here, so Y is downwards.
    _drawComponentInfo(
      canvas,
      symbolInstance,
      paint,
      mirrorX,
      mirrorY,
      rotation,
    );
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

        case Arc:
          _drawArc(
            canvas,
            graphic as Arc,
            paint,
            fillPaint,
            isSelected,
            mx,
            my,
          );
          break;
      }
    }

    // Draw pins
    for (final pin in unit.pins) {
      _drawPin(canvas, pin, paint, showPinNumbers, mx, my);
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

  /// Draw an arc graphic element, applying mirroring.
  void _drawArc(
    ui.Canvas canvas,
    Arc arc,
    Paint paint,
    Paint fillPaint,
    bool isSelected,
    double mx,
    double my,
  ) {
    // Apply mirroring to points
    final start = Offset(arc.start.x * mx, arc.start.y * my);
    final mid = Offset(arc.mid.x * mx, arc.mid.y * my);
    final end = Offset(arc.end.x * mx, arc.end.y * my);

    // Calculate arc parameters from three points
    final center = _calculateArcCenter(start, mid, end);
    final radius = _calculateArcRadius(center, start);
    if (center == null || radius == null) {
      // Fallback: draw as lines if arc calculation fails
      final path = ui.Path();
      path.moveTo(start.dx, start.dy);
      path.lineTo(mid.dx, mid.dy);
      path.lineTo(end.dx, end.dy);
      canvas.drawPath(path, paint);
      return;
    }

    final angles = _calculateArcAngles(center, start, end, mid);

    if (angles == null) {
      // Fallback: draw as lines if arc calculation fails
      final path = ui.Path();
      path.moveTo(start.dx, start.dy);
      path.lineTo(mid.dx, mid.dy);
      path.lineTo(end.dx, end.dy);
      canvas.drawPath(path, paint);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = angles.$1;
    final sweepAngle = angles.$2;

    // Draw the arc
    Paint arcPaint = isSelected ? (paint..color = Colors.blue) : paint;
    Paint arcFillPaint = isSelected
        ? (fillPaint..color = Colors.blue.withOpacity(0.3))
        : fillPaint;

    if (arc.fill.type != FillType.none) {
      canvas.drawArc(rect, startAngle, sweepAngle, true, arcFillPaint);
    }
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  /// Calculate the center of an arc given three points
  Offset? _calculateArcCenter(Offset start, Offset mid, Offset end) {
    // Calculate perpendicular bisectors
    final mid1 = Offset((start.dx + mid.dx) / 2, (start.dy + mid.dy) / 2);
    final dir1 = Offset(mid.dx - start.dx, mid.dy - start.dy);
    final perp1 = Offset(-dir1.dy, dir1.dx);

    final mid2 = Offset((mid.dx + end.dx) / 2, (mid.dy + end.dy) / 2);
    final dir2 = Offset(end.dx - mid.dx, end.dy - mid.dy);
    final perp2 = Offset(-dir2.dy, dir2.dx);

    // Find intersection of perpendicular bisectors
    final denom = perp1.dx * perp2.dy - perp1.dy * perp2.dx;
    if (denom.abs() < 1e-10) return null; // Parallel lines

    final t =
        ((mid2.dx - mid1.dx) * perp2.dy - (mid2.dy - mid1.dy) * perp2.dx) /
        denom;
    return Offset(mid1.dx + t * perp1.dx, mid1.dy + t * perp1.dy);
  }

  /// Calculate the radius of an arc
  double? _calculateArcRadius(Offset? center, Offset point) {
    if (center == null) return null;
    final diff = point - center;
    return math.sqrt(diff.dx * diff.dx + diff.dy * diff.dy);
  }

  /// Calculate start angle and sweep angle for an arc
  (double, double)? _calculateArcAngles(
    Offset center,
    Offset start,
    Offset end,
    Offset mid,
  ) {
    if (center == null) return null;

    final startVector = start - center;
    final endVector = end - center;
    final midVector = mid - center;

    final startAngle = math.atan2(startVector.dy, startVector.dx);
    final endAngle = math.atan2(endVector.dy, endVector.dx);
    final midAngle = math.atan2(midVector.dy, midVector.dx);

    // Determine sweep direction based on mid point
    var sweepAngle = endAngle - startAngle;

    // Check if mid point suggests clockwise or counterclockwise sweep
    final midDiff =
        (midAngle - startAngle + 3 * math.pi) % (2 * math.pi) - math.pi;
    final endDiff =
        (endAngle - startAngle + 3 * math.pi) % (2 * math.pi) - math.pi;

    if ((midDiff > 0 && endDiff < 0) || (midDiff < 0 && endDiff > 0)) {
      // Different signs, need to determine correct direction
      if (midDiff.abs() < math.pi && endDiff.abs() > math.pi) {
        sweepAngle = -sweepAngle;
      } else if (midDiff.abs() > math.pi && endDiff.abs() < math.pi) {
        sweepAngle = -sweepAngle;
      }
    }

    // Normalize sweep angle to be between -2π and 2π
    while (sweepAngle > 2 * math.pi) sweepAngle -= 2 * math.pi;
    while (sweepAngle < -2 * math.pi) sweepAngle += 2 * math.pi;

    return (startAngle, sweepAngle);
  }

  /// Draw a pin, applying mirroring.
  void _drawPin(
    ui.Canvas canvas,
    Pin pin,
    Paint paint,
    bool showPinNumbers,
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

    // canvas.drawCircle(startPos, 0.2, paint);  // connection point!

    // Pin text will be drawn separately outside canvas transformations to avoid mirroring
  }

  /// Draw pin number and name text.
  /// Text position is mirrored, but the text itself is not, to maintain readability.
  void _drawPinText(
    ui.Canvas canvas,
    Pin pin,
    Paint paint,
    bool showPinNumbers,
    double mx,
    double my,
    double rotation,
  ) {
    // Calculate effective pin angle again for correct text orientation (new method)
    final rotationRad = rotation * (math.pi / 180);
    // final angleRad = angle + rotationRad;
    //final startPos = Offset(pin.position.x * mx, pin.position.y * my);
    final rotatedPinPositionX =
        pin.position.x * math.cos(rotationRad) -
        pin.position.y * math.sin(rotationRad);
    final rotatedPinPositionY =
        pin.position.x * math.sin(rotationRad) +
        pin.position.y * math.cos(rotationRad);

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
          numberOffset = Offset(0, 0.2);
        } else if (effectivePinAngle >= 45 && effectivePinAngle < 135) {
          // Bottom side
          numberOffset = Offset(-0.2, 0);
          angleRad = 90.0 * math.pi / 180.0;
        } else if (effectivePinAngle >= 135 && effectivePinAngle < 225) {
          // Right side
          numberOffset = Offset(-pin.length + 0.2, 0.2);
        } else {
          // Top side
          numberOffset = Offset(-0.2, -pin.length + 0.2);
          angleRad = 90.0 * math.pi / 180.0;
        }

        canvas.save();
        canvas.translate(
          (rotatedPinPositionX + numberOffset.dx) * mx,
          (rotatedPinPositionY + numberOffset.dy) * my,
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
        final effectivePinAngle = ((pin.angle + rotation) + 360) % 360;

        if (effectivePinAngle >= 315 || effectivePinAngle < 45) {
          // 0
          // Left side
          nameOffset = Offset(pin.length + distance, 0);
        } else if (effectivePinAngle >= 45 && effectivePinAngle < 135) {
          // 90
          // Bottom side
          nameOffset = Offset(0, pin.length + distance);
          angleRad = 90.0 * math.pi / 180.0;
        } else if (effectivePinAngle >= 135 && effectivePinAngle < 225) {
          // 180
          // Right side
          nameOffset = Offset(-pin.length - textPainter.width - distance, 0);
        } else {
          // 270
          // Top side
          nameOffset = Offset(0, -pin.length - textPainter.width - distance);
          angleRad = 90.0 * math.pi / 180.0;
        }

        canvas.save();
        canvas.translate(
          (rotatedPinPositionX + nameOffset.dx) * mx,
          (rotatedPinPositionY + nameOffset.dy) * my,
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

  /// Draw component ID and value.
  /// This is drawn in a separate canvas context, so transformations are simpler.
  void _drawComponentInfo(
    ui.Canvas canvas,
    SymbolInstance symbol,
    Paint paint,
    bool mirrorX,
    bool mirrorY,
    double rotation,
  ) {
    for (final property in symbol.properties) {
      if ((property.name != 'Value' && property.name != 'Reference') ||
          property.value.isEmpty ||
          property.hidden ||
          property.effects.hide) {
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
      canvas.save();
      canvas.translate(property.position.x, property.position.y);
      canvas.rotate(calcSafeAngleRad(property.position.angle + rotation));
      // var x = property.position.x;
      // var y = property.position.y;

      // if (mirrorY) x = -x; // Mirror around Y-axis affects X coord
      // if (mirrorX) y = -y; // Mirror around X-axis affects Y coord
      final double spacing = 0;

      final offset = switch (property.effects.justify) {
        Justify.left => Offset(0, spacing),
        Justify.center => Offset(
          -propertyPainter.width / 2,
          -propertyPainter.height / 2,
        ),
        Justify.right => Offset(-propertyPainter.width, spacing),
        Justify.top => Offset(0, spacing),
        Justify.bottom => Offset(0, -propertyPainter.height - spacing),
        Justify.topLeft => Offset(0, 0),
        Justify.topRight => Offset(-propertyPainter.width, spacing),
        Justify.bottomLeft => Offset(0, -propertyPainter.height - spacing),
        Justify.bottomRight => Offset(
          -propertyPainter.width,
          -propertyPainter.height - spacing,
        ),
      };

      propertyPainter.paint(canvas, offset);
      canvas.restore();

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
    LibrarySymbol symbol,
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
  Rect getSymbolBounds(LibrarySymbol symbol) {
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final unit in symbol.units) {
      for (final graphic in unit.graphics) {
        if (graphic is Rectangle) {
          minX = math.min(minX, graphic.start.x);
          maxX = math.max(maxX, graphic.end.x);
          minY = math.min(minY, graphic.start.y);
          maxY = math.max(maxY, graphic.end.y);
        } else if (graphic is Circle) {
          final center = graphic.center;
          final radius = graphic.radius;
          minX = math.min(minX, center.x - radius);
          maxX = math.max(maxX, center.x + radius);
          minY = math.min(minY, center.y - radius);
          maxY = math.max(maxY, center.y + radius);
        } else if (graphic is Arc) {
          // Include all three points that define the arc
          minX = math.min(minX, graphic.start.x);
          maxX = math.max(maxX, graphic.start.x);
          minY = math.min(minY, graphic.start.y);
          maxY = math.max(maxY, graphic.start.y);

          minX = math.min(minX, graphic.mid.x);
          maxX = math.max(maxX, graphic.mid.x);
          minY = math.min(minY, graphic.mid.y);
          maxY = math.max(maxY, graphic.mid.y);

          minX = math.min(minX, graphic.end.x);
          maxX = math.max(maxX, graphic.end.x);
          minY = math.min(minY, graphic.end.y);
          maxY = math.max(maxY, graphic.end.y);
        } else if (graphic is Polyline) {
          for (final point in graphic.points) {
            minX = math.min(minX, point.x);
            maxX = math.max(maxX, point.x);
            minY = math.min(minY, point.y);
            maxY = math.max(maxY, point.y);
          }
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
