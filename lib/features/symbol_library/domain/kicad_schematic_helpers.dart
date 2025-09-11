import 'dart:ui';
import 'dart:math' as math;

import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_models.dart';

/// Calculates the absolute position of a symbol pin on the schematic.
///
/// Takes into account the symbol's position, rotation, and mirroring.
/// The calculation logic is derived from the rendering transformations in
/// `kicad_symbol_renderer.dart` to ensure consistency.
///
/// - [instance]: The symbol instance on the schematic.
/// - [pin]: The pin definition from the symbol library.
///
/// Returns an [Offset] with the absolute (x, y) coordinates of the pin.
Offset getPinAbsolutePosition(SymbolInstance instance, Pin pin) {

  final px = pin.position.x;
  final py = pin.position.y;

  // Transformation factors from renderer logic.
  // Note: mirrorY flips horizontally (around Y-axis), affecting the X coordinate.
  //       mirrorX flips vertically (around X-axis), affecting the Y coordinate.
  final mx = instance.mirrory ? -1.0 : 1.0;
  final my = instance.mirrorx ? -1.0 : 1.0;

  // The transformation pipeline must match the renderer's canvas operations exactly.
  // 1. Apply mirroring to the pin's relative coordinates.
  // 2. Apply rotation.
  // 3. Apply translation (the instance's position).
  // The Y-coordinate is inverted because KiCad's schematic editor has a Y-down coordinate system,
  // but the symbol definitions have Y-up.

  final transformedPx = px * mx; // Apply mirror
  final transformedPy = py * my; // Apply mirror

  final rotRad = instance.at.angle * (math.pi / 180.0); // Convert degrees to radians and invert for Y-down
  final cosRot = math.cos(rotRad);
  final sinRot = math.sin(rotRad);

  // Apply rotation to the transformed (mirrored) point
  // x′ = x⋅cos(a)−y⋅sin(a)
  // y′ = x⋅sin(a)+y⋅cos(a)
  final rotatedX = transformedPx * cosRot - transformedPy * sinRot;
  final rotatedY = -transformedPx * sinRot - transformedPy * cosRot;   // y is inverted

  // Translate to the final absolute position
  final pFinalX = rotatedX + instance.at.x;
  final pFinalY = rotatedY + instance.at.y;

  return Offset(pFinalX, pFinalY);
}
