import 'dart:ui';
import 'dart:math' as math;

import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_models.dart';

/// Pomocnicza funkcja do pobierania czytelnego deskryptora (np. "R1") na podstawie UUID instancji.
// String getSymbolDesignator(SymbolInstance symbol) {

//   final refP = symbol.properties.where((prop) => prop.name == 'Reference');
//   if (refP.isEmpty) return symbol.libId;
//   return refP.first.value;
// }
// /// Pomocnicza funkcja do pobierania wartości instancji symbolu (np. "R1") na podstawie UUID instancji.
// String getSymbolValue(SymbolInstance symbol) {

//   final refP = symbol.properties.where((prop) => prop.name == 'Value');
//   if (refP.isEmpty) return symbol.libId;
//   return refP.first.value;
// }



/// Calculates the absolute position of a symbol pin on the schematic.
///
/// Takes into account the symbol's position, rotation, and mirroring.
/// The calculation logic is derived from the rendering transformations in
/// `kicad_symbol_renderer.dart` to ensure consistency but remember:
/// - coordinates of instance.at is Y-growup-down, and must be flipped in renderer!
/// - symbol definition is Y-growup-up so is not flipped in renderer!
/// - this function returns Y-growup-down coordinates, as used in the schematic editor and then can't be flipped!
/// - symbol definition is Y-growup-up, so symbol pins y offsets must be flipped here to Y-growup-down system!
///
/// - [instance]: The symbol instance on the schematic.
/// - [pin]: The pin definition from the symbol library.
///
/// Returns an [Offset] with the absolute (x, y) coordinates of the pin.
Offset getPinAbsolutePosition(SymbolInstance instance, Pin pin) {

  final px = pin.position.x;
  final py = pin.position.y;

  // Transformation factors from renderer logic.
  // Note: mirrorX flips around X-axis, affecting the Y coordinate.
  //       mirrorY flips around Y-axis, affecting the X coordinate.
  final mx = instance.mirrorx ? -1.0 : 1.0;
  final my = instance.mirrory ? -1.0 : 1.0;

  // The transformation pipeline must match the renderer's canvas operations exactly.
  // 1. Apply mirroring to the pin's relative coordinates.
  // 2. Apply rotation.
  // 3. Apply translation (the instance's position).
  // The Y-coordinate is inverted because KiCad's schematic editor has a Y-down coordinate system,
  // but the symbol definitions have Y-up.

  // final rotRad = instance.at.angle * (math.pi / 180.0); // Convert degrees to radians and invert for Y-down
  // final cosRot = math.cos(rotRad);
  // final sinRot = math.sin(rotRad);

  // Don't apply rotation to the transformed (mirrored) point!
  // // x′ = x⋅cos(a)−y⋅sin(a)
  // // y′ = x⋅sin(a)+y⋅cos(a)

  final rotRad = instance.at.angle * (math.pi / 180.0); // Convert degrees to radians and invert for Y-down
  final cosRot = math.cos(rotRad);
  final sinRot = math.sin(rotRad);

  // First (!) apply rotation to the point
  // x′ = x⋅cos(a)−y⋅sin(a)
  // y′ = x⋅sin(a)+y⋅cos(a)
  final rotatedX = px * cosRot - py * sinRot;
  final rotatedY = -px * sinRot - py * cosRot;   // y is inverted (instance.at is Y-growup-down, symbol definition is Y-growup-up so have to be inverted here)

  // Apply mirroring to the pin's relative coordinates.
  final mirroredX = rotatedX * my; // Apply mirror y to x coordinate
  final mirroredY = rotatedY * mx; // Apply mirror x to y coordinate
  
  // Translate to the final absolute position (agreed with schematic editor y-group-down coordinates).
  final pFinalX = mirroredX + instance.at.x;
  final pFinalY = mirroredY + instance.at.y;

  return Offset(pFinalX, pFinalY);
}
