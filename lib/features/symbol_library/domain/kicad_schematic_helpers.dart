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
  final ix = instance.at.x;
  final iy = instance.at.y;
  final rotationDegrees = instance.at.angle;
  final mirrorX = instance.mirrorx;
  final mirrorY = instance.mirrory;

  final px = pin.position.x;
  final py = pin.position.y;

  // Transformation factors from renderer logic.
  // Note: mirrorY flips horizontally (around Y-axis), affecting the X coordinate.
  //       mirrorX flips vertically (around X-axis), affecting the Y coordinate.
  final mx = mirrorY ? -1.0 : 1.0;
  final my = mirrorX ? -1.0 : 1.0;

  final rotRad = rotationDegrees * (math.pi / 180.0);

  // The transformation pipeline mimics the canvas operations seen in the renderer.
  // The formula is a direct calculation of the transformation matrix applied to the pin's relative coordinates.
  // It combines Y-inversion for KiCad's coordinate system, rotation, mirroring, and finally translation.
  //
  // Formula derived from renderer's canvas operations:
  // p_final_x = (px*cos(rot) - py*sin(rot)) * mx + ix
  // p_final_y = (-px*sin(rot) - py*cos(rot)) * my + iy

  final cosRot = math.cos(rotRad);
  final sinRot = math.sin(rotRad);

  final pFinalX = (px * cosRot - py * sinRot) * mx + ix;
  final pFinalY = (-px * sinRot - py * cosRot) * my + iy;

  return Offset(pFinalX, pFinalY);
}
