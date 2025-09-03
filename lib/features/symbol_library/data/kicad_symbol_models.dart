// KiCad Symbol Data Models

// === Core Data Model ===

sealed class KiCadElement {}

final class KiCadLibrary extends KiCadElement {
  final String version;
  final String generator;
  final List<LibrarySymbol> librarySymbols;

  KiCadLibrary({
    required this.version,
    required this.generator,
    required this.librarySymbols,
  });

  @override
  String toString() => 'KiCadLibrary(v$version, ${librarySymbols.length} symbols)';
}

final class LibrarySymbol extends KiCadElement {
  final String name;
  final PinNames pinNames;
  final bool inBom;
  final bool hidePinNumbers;
  final bool onBoard;
  final List<Property> properties;
  final List<SymbolUnit> units;
  final bool excludeFromSim;
  final bool embeddedFonts;

  LibrarySymbol({
    required this.name,
    required this.pinNames,
    required this.inBom,
    required this.hidePinNumbers,
    required this.onBoard,
    required this.properties,
    required this.units,
    this.excludeFromSim = false,
    this.embeddedFonts = false,
  });

  @override
  String toString() =>
      'LibrarySymbol($name, ${properties.length} props, ${units.length} units)';
}

final class PinNames {
  final double offset;

  const PinNames({required this.offset});
}

final class Property extends KiCadElement {
  final String name;
  final String value;
  final Position position;
  final TextEffects effects;
  final bool hidden;

  Property({
    required this.name,
    required this.value,
    required this.position,
    required this.effects,
    this.hidden = false,
  });

  @override
  String toString() => 'Property($name: $value)';
}

final class SymbolUnit extends KiCadElement {
  final String name;
  final int unitNumber;
  final List<GraphicElement> graphics;
  final List<Pin> pins;

  SymbolUnit({
    required this.name,
    required this.unitNumber,
    required this.graphics,
    required this.pins,
  });

  @override
  String toString() => 'SymbolUnit($name, ${pins.length} pins)';
}

sealed class GraphicElement extends KiCadElement {}

final class Rectangle extends GraphicElement {
  final Position start;
  final Position end;
  final Stroke stroke;
  final Fill fill;

  Rectangle({
    required this.start,
    required this.end,
    required this.stroke,
    required this.fill,
  });
}

final class Circle extends GraphicElement {
  final Position center;
  final double radius;
  final Stroke stroke;
  final Fill fill;

  Circle({
    required this.center,
    required this.radius,
    required this.stroke,
    required this.fill,
  });
}

final class Polyline extends GraphicElement {
  final List<Position> points;
  final Stroke stroke;
  final Fill fill;

  Polyline({required this.points, required this.stroke, required this.fill});
}

final class Arc extends GraphicElement {
  final Position start;
  final Position mid;
  final Position end;
  final Stroke stroke;
  final Fill fill;

  Arc({
    required this.start,
    required this.mid,
    required this.end,
    required this.stroke,
    required this.fill,
  });
}

final class Pin extends KiCadElement {
  final PinType type;
  final PinStyle style;
  final Position position;
  final double angle;
  final double length;
  final String name;
  final String number;
  final TextEffects nameEffects;
  final TextEffects numberEffects;

  Pin({
    required this.type,
    required this.style,
    required this.position,
    required this.angle,
    required this.length,
    required this.name,
    required this.number,
    required this.nameEffects,
    required this.numberEffects,
  });

  @override
  String toString() => 'Pin($number: $name, $type)';
}

// === Supporting Data Structures ===

enum PinType {
  input,
  output,
  bidirectional,
  tristate,
  passive,
  unspecified,
  powerIn,
  powerOut,
  openCollector,
  openEmitter,
  notConnected,
}

enum PinStyle {
  line,
  inverted,
  clock,
  invertedClock,
  inputLow,
  clockLow,
  outputLow,
  edgeClockHigh,
  nonLogic,
}

final class Position {
  final double x;
  final double y;
  final double angle;

  const Position(this.x, this.y, [this.angle = 0.0]);

  @override
  String toString() => '($x, $y${angle != 0 ? ', ${angle}°' : ''})';

  Position operator +(Position other) =>
      Position(x + other.x, y + other.y, angle + other.angle);
  Position operator -(Position other) =>
      Position(x - other.x, y - other.y, angle - other.angle);
}

final class TextEffects {
  final Font font;
  final Justify justify;
  final bool hide;

  const TextEffects({
    required this.font,
    required this.justify,
    this.hide = false,
  });
}

final class Font {
  final double width;
  final double height;

  const Font({required this.width, required this.height});
}

enum Justify {
  left,
  right,
  center,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}



final class Stroke {
  final double width;

  const Stroke({required this.width});
}

enum FillType { none, outline, background }

final class Fill {
  final FillType type;

  const Fill({required this.type});
}

// S-Expression Data Models
sealed class SExpr {}

final class SAtom extends SExpr {
  final String value;
  SAtom(this.value);
  @override
  String toString() => value;
}

final class SList extends SExpr {
  final List<SExpr> elements;
  SList(this.elements);
  @override
  String toString() => '(${elements.join(' ')})';
}

final class ParseResult<T> {
  final T? value;
  final String? error;
  final bool success;

  const ParseResult.success(this.value) : error = null, success = true;
  const ParseResult.failure(this.error) : value = null, success = false;

  R fold<R>(R Function(T) onSuccess, R Function(String) onFailure) =>
      success ? onSuccess(value!) : onFailure(error!);
}
