// KiCad Symbol Library Parser
// Functional parser using Dart's modern pattern matching and immutable data structures

import 'dart:io';
import 'dart:convert';
import '../data/kicad_symbol_models.dart';

import 'kicad_sexpr_parser.dart';
import 'kicad_tokenizer.dart';

// === Parser Implementation ===

// === Semantic Parser ===

final class KiCadParser {
  static ParseResult<KiCadLibrary> parseLibrary(String content) {
    final tokenizer = Tokenizer(content);
    final tokens = tokenizer.tokenize();
    final sexprParser = SExprParser(tokens);

    return sexprParser.parse().fold(
      (sexprs) => _parseLibraryFromSExprs(sexprs),
      (error) => ParseResult.failure(error),
    );
  }

  static ParseResult<KiCadLibrary> _parseLibraryFromSExprs(List<SExpr> sexprs) {
    try {
      // Look for either kicad_symbol_lib or kicad_sch format
      final libraryExpr =
          sexprs.firstWhere(
                (expr) => switch (expr) {
                  SList(
                    elements: [
                      SAtom(value: 'kicad_symbol_lib' || 'kicad_sch'),
                      ...,
                    ],
                  ) =>
                    true,
                  _ => false,
                },
                orElse: () =>
                    throw Exception('No kicad_symbol_lib or kicad_sch found'),
              )
              as SList;

      return ParseResult.success(parseLibraryExpr(libraryExpr));
    } catch (e) {
      return ParseResult.failure('Library parsing error: $e');
    }
  }

  static KiCadLibrary parseLibraryExpr(SList expr) {
    var version = '20211014';
    var generator = 'unknown';
    final librarySymbols = <LibrarySymbol>[];

    for (final element in expr.elements.skip(1)) {
      switch (element) {
        case SList(
          elements: [SAtom(value: 'version'), SAtom(value: final v), ...],
        ):
          version = v;
        case SList(
          elements: [SAtom(value: 'generator'), SAtom(value: final g), ...],
        ):
          generator = g;
        case SList(
          elements: [
            SAtom(value: 'symbol'),
            SAtom(value: final name),
            ...final rest,
          ],
        ):
          var symbol = parseLibrarySymbol(name, rest);
          librarySymbols.add(symbol);
        default:
          break;
      }
    }

    return KiCadLibrary(
      version: version,
      generator: generator,
      librarySymbols: librarySymbols,
    );
  }

  static LibrarySymbol parseLibrarySymbol(String name, List<SExpr> elements) {
    var pinNames = const PinNames(offset: 1.016);
    var inBom = true;
    var onBoard = true;
    var hidePinNumbers = false;
    var excludeFromSim = false;
    var embeddedFonts = false;
    final properties = <Property>[];
    final units = <SymbolUnit>[];

    for (final element in elements) {
      switch (element) {
        case SList(
          elements: [
            SAtom(value: 'pin_names'),
            SList(
              elements: [SAtom(value: 'offset'), SAtom(value: final v), ...],
            ),
            ...,
          ],
        ):
          pinNames = PinNames(offset: double.parse(v));

        case SList(
          elements: [
            SAtom(value: 'pin_numbers'),
            SList(elements: [SAtom(value: 'hide'), SAtom(value: final v)]),
            ...,
          ],
        ):
          hidePinNumbers = v == 'yes';

        case SList(
          elements: [SAtom(value: 'in_bom'), SAtom(value: final v), ...],
        ):
          inBom = v == 'yes';

        case SList(
          elements: [SAtom(value: 'on_board'), SAtom(value: final v), ...],
        ):
          onBoard = v == 'yes';

        case SList(
            elements: [SAtom(value: 'exclude_from_sim'), SAtom(value: final v), ...]):
          excludeFromSim = v == 'yes';

        case SList(elements: [SAtom(value: 'embedded_fonts'), ...]):
          embeddedFonts = true;

        case SList(elements: [SAtom(value: 'property'), ...final propElements]):
          properties.add(parseProperty(propElements));

        case SList(
          elements: [
            SAtom(value: 'symbol'),
            SAtom(value: final unitName),
            ...final unitElements,
          ],
        ):
          units.add(parseSymbolUnit(unitName, unitElements));

        default:
          break;
      }
    }

    return LibrarySymbol(
      name: name,
      pinNames: pinNames,
      inBom: inBom,
      hidePinNumbers: hidePinNumbers,
      onBoard: onBoard,
      properties: properties,
      units: units,
      excludeFromSim: excludeFromSim,
      embeddedFonts: embeddedFonts,
    );
  }

  static Property parseProperty(List<SExpr> elements) {
    final name = (elements[0] as SAtom).value;
    final value = (elements[1] as SAtom).value;
    var position = const Position(0, 0);
    var hidden = false;
    var effects = const TextEffects(
      font: Font(width: 1.27, height: 1.27),
      justify: Justify.left,
    );
    // print("parseProperty: $name, $value");

    for (final element in elements.skip(2)) {
      switch (element) {
        case SList(
          elements: [
            SAtom(value: 'at'),
            SAtom(value: final x),
            SAtom(value: final y),
            SAtom(value: final angle),
            ...,
          ],
        ):
          position = Position(
            double.parse(x),
            double.parse(y),
            double.parse(angle),
          );
        case SList(
          elements: [SAtom(value: 'effects'), ...final effectElements],
        ):
          effects = parseTextEffects(effectElements);
        case SAtom(value: 'hide'):
          hidden = true;
        default:
          break;
      }
    }

    return Property(
      name: name,
      value: value,
      position: position,
      effects: effects,
      hidden: hidden,
    );
  }

  static SymbolUnit parseSymbolUnit(String name, List<SExpr> elements) {
    final graphics = <GraphicElement>[];
    final pins = <Pin>[];
    final unitNumberMatch = RegExp(r'_(\d+)_\d+$').firstMatch(name);
    final unitNumber = unitNumberMatch?.group(1) != null
        ? int.parse(unitNumberMatch!.group(1)!)
        : 0;

    for (final element in elements) {
      switch (element) {
        case SList(
          elements: [SAtom(value: 'rectangle'), ...final rectElements],
        ):
          graphics.add(parseRectangle(rectElements));

        case SList(elements: [SAtom(value: 'circle'), ...final circleElements]):
          graphics.add(parseCircle(circleElements));

        case SList(
          elements: [SAtom(value: 'polyline'), ...final polylineElements],
        ):
          graphics.add(parsePolyline(polylineElements));

        case SList(elements: [SAtom(value: 'arc'), ...final arcElements]):
          graphics.add(parseArc(arcElements));

        case SList(elements: [SAtom(value: 'pin'), ...final pinElements]):
          pins.add(parsePin(pinElements));

        default:
          break;
      }
    }

    return SymbolUnit(
      name: name,
      unitNumber: unitNumber,
      graphics: graphics,
      pins: pins,
    );
  }

  static Rectangle parseRectangle(List<SExpr> elements) {
    Position? start, end;
    var stroke = const Stroke(width: 0.254);
    var fill = const Fill(type: FillType.none);

    for (final element in elements) {
      switch (element) {
        case SList(
          elements: [
            SAtom(value: 'start'),
            SAtom(value: final x),
            SAtom(value: final y),
            ...,
          ],
        ):
          start = Position(double.parse(x), double.parse(y));
        case SList(
          elements: [
            SAtom(value: 'end'),
            SAtom(value: final x),
            SAtom(value: final y),
            ...,
          ],
        ):
          end = Position(double.parse(x), double.parse(y));
        case SList(
          elements: [
            SAtom(value: 'stroke'),
            SList(
              elements: [SAtom(value: 'width'), SAtom(value: final w), ...],
            ),
            ...,
          ],
        ):
          stroke = Stroke(width: double.parse(w));
        case SList(
          elements: [
            SAtom(value: 'fill'),
            SList(elements: [SAtom(value: 'type'), SAtom(value: final t), ...]),
            ...,
          ],
        ):
          fill = Fill(type: parseFillType(t));
        default:
          break;
      }
    }

    return Rectangle(
      start: start ?? const Position(0, 0),
      end: end ?? const Position(0, 0),
      stroke: stroke,
      fill: fill,
    );
  }

  static Circle parseCircle(List<SExpr> elements) {
    Position? center;
    double radius = 0;
    var stroke = const Stroke(width: 0.254);
    var fill = const Fill(type: FillType.none);

    for (final element in elements) {
      switch (element) {
        case SList(
          elements: [
            SAtom(value: 'center'),
            SAtom(value: final x),
            SAtom(value: final y),
            ...,
          ],
        ):
          center = Position(double.parse(x), double.parse(y));

        case SList(
          elements: [SAtom(value: 'radius'), SAtom(value: final r), ...],
        ):
          radius = double.parse(r);

        case SList(
          elements: [
            SAtom(value: 'stroke'),
            SList(
              elements: [SAtom(value: 'width'), SAtom(value: final w), ...],
            ),
            ...,
          ],
        ):
          stroke = Stroke(width: double.parse(w));

        case SList(
          elements: [
            SAtom(value: 'fill'),
            SList(elements: [SAtom(value: 'type'), SAtom(value: final t), ...]),
            ...,
          ],
        ):
          fill = Fill(type: parseFillType(t));
        default:
          break;
      }
    }

    return Circle(
      center: center ?? const Position(0, 0),
      radius: radius,
      stroke: stroke,
      fill: fill,
    );
  }

  static Polyline parsePolyline(List<SExpr> elements) {
    final points = <Position>[];
    var stroke = const Stroke(width: 0.254);
    var fill = const Fill(type: FillType.none);

    // print('Parsing polyline with elements: $elements');

    for (final element in elements) {
      switch (element) {
        case SList(elements: [SAtom(value: 'pts'), ...final pointElements]):
          for (final point in pointElements) {
            if (point case SList(
              elements: [
                SAtom(value: 'xy'),
                SAtom(value: final x),
                SAtom(value: final y),
              ],
            )) {
              points.add(Position(double.parse(x), double.parse(y)));
            }
          }

        case SList(
          elements: [
            SAtom(value: 'stroke'),
            SList(
              elements: [SAtom(value: 'width'), SAtom(value: final w), ...],
            ),
            ...,
          ],
        ):
          stroke = Stroke(width: double.parse(w));

        case SList(
          elements: [
            SAtom(value: 'fill'),
            SList(elements: [SAtom(value: 'type'), SAtom(value: final t), ...]),
            ...,
          ],
        ):
          fill = Fill(type: parseFillType(t));
        default:
          break;
      }
    }

    return Polyline(points: points, stroke: stroke, fill: fill);
  }

  static Arc parseArc(List<SExpr> elements) {
    Position? start, mid, end;
    var stroke = const Stroke(width: 0.254);
    var fill = const Fill(type: FillType.none);

    for (final element in elements) {
      switch (element) {
        case SList(
          elements: [
            SAtom(value: 'start'),
            SAtom(value: final x),
            SAtom(value: final y),
            ...,
          ],
        ):
          start = Position(double.parse(x), double.parse(y));
        case SList(
          elements: [
            SAtom(value: 'mid'),
            SAtom(value: final x),
            SAtom(value: final y),
            ...,
          ],
        ):
          mid = Position(double.parse(x), double.parse(y));
        case SList(
          elements: [
            SAtom(value: 'end'),
            SAtom(value: final x),
            SAtom(value: final y),
            ...,
          ],
        ):
          end = Position(double.parse(x), double.parse(y));
        case SList(
          elements: [
            SAtom(value: 'stroke'),
            SList(
              elements: [SAtom(value: 'width'), SAtom(value: final w), ...],
            ),
            ...,
          ],
        ):
          stroke = Stroke(width: double.parse(w));
        case SList(
          elements: [
            SAtom(value: 'fill'),
            SList(elements: [SAtom(value: 'type'), SAtom(value: final t), ...]),
            ...,
          ],
        ):
          fill = Fill(type: parseFillType(t));
        default:
          break;
      }
    }

    return Arc(
      start: start ?? const Position(0, 0),
      mid: mid ?? const Position(0, 0),
      end: end ?? const Position(0, 0),
      stroke: stroke,
      fill: fill,
    );
  }

  static Pin parsePin(List<SExpr> elements) {
    var type = PinType.unspecified;
    var style = PinStyle.line;
    var position = const Position(0, 0);
    var length = 2.54;
    var name = '';
    var number = '';
    var nameEffects = const TextEffects(
      font: Font(width: 1.016, height: 1.016),
      justify: Justify.left,
    );
    var numberEffects = const TextEffects(
      font: Font(width: 1.016, height: 1.016),
      justify: Justify.left,
    );

    // Parse pin type and style
    if (elements case [SAtom(value: final typeStr), ...]) {
      type = parsePinType(typeStr);
    }
    if (elements case [_, SAtom(value: final styleStr), ...]) {
      style = parsePinStyle(styleStr);
    }

    for (final element in elements.skip(2)) {
      switch (element) {
        case SList(
          elements: [
            SAtom(value: 'at'),
            SAtom(value: final x),
            SAtom(value: final y),
            SAtom(value: final angle),
            ...,
          ],
        ):
          {
            var xv = double.parse(x);
            var yv = double.parse(y);
            var av = double.parse(angle);

            position = Position(
              xv,
              yv, // KiCad uses inverted Y axis
              av,
            );
          }
        case SList(
          elements: [SAtom(value: 'length'), SAtom(value: final l), ...],
        ):
          length = double.parse(l);
        case SList(
          elements: [SAtom(value: 'name'), SAtom(value: final n), ...],
        ):
          name = n;
        case SList(
          elements: [SAtom(value: 'number'), SAtom(value: final n), ...],
        ):
          number = n;
        default:
          break;
      }
    }

    return Pin(
      type: type,
      style: style,
      position: position,
      angle: position.angle,
      length: length,
      name: name,
      number: number,
      nameEffects: nameEffects,
      numberEffects: numberEffects,
    );
  }

  // === Helper Parsers ===

  static Position parsePosition(List<double> coords) {
    return switch (coords.length) {
      >= 3 => Position(coords[0], coords[1], coords[2]),
      >= 2 => Position(coords[0], coords[1]),
      _ => const Position(0, 0),
    };
  }

  static TextEffects parseTextEffects(List<SExpr> elements) {
    var font = const Font(width: 1.27, height: 1.27);
    var justify = Justify.center; // Default justification -> no justification
    var hide = false;

    for (final element in elements) {
      switch (element) {
        case SList(
          elements: [
            SAtom(value: 'font'),
            SList(
              elements: [
                SAtom(value: 'size'),
                SAtom(value: final w),
                SAtom(value: final h),
                ...,
              ],
            ),
            ...,
          ],
        ):
          font = Font(width: double.parse(w), height: double.parse(h));

        case SList(
          elements: [
            SAtom(value: 'justify'),
            SAtom(value: final i),
            SAtom(value: final j),
            ...,
          ],
        ):
          // print("Parse justify: $i, $j");
          justify = parseJustify2(i, j);

        case SList(
          elements: [SAtom(value: 'justify'), SAtom(value: final j), ...],
        ):
          // print("Parse justify: $j");
          justify = parseJustify(j);

        case SList(elements: [SAtom(value: 'hide'), SAtom(value: 'yes'), ...]):
          hide = true;
          break;
        case SAtom(value: 'hide'): // Also handle the keyword form
          hide = true;
          break;
        default:
          break;
      }
    }

    return TextEffects(font: font, justify: justify, hide: hide);
  }

  static PinType parsePinType(String type) => switch (type) {
    'input' => PinType.input,
    'output' => PinType.output,
    'bidirectional' => PinType.bidirectional,
    'tri_state' => PinType.tristate,
    'passive' => PinType.passive,
    'power_in' => PinType.powerIn,
    'power_out' => PinType.powerOut,
    'open_collector' => PinType.openCollector,
    'open_emitter' => PinType.openEmitter,
    'no_connect' => PinType.notConnected,
    _ => PinType.unspecified,
  };

  static PinStyle parsePinStyle(String style) => switch (style) {
    'line' => PinStyle.line,
    'inverted' => PinStyle.inverted,
    'clock' => PinStyle.clock,
    'inverted_clock' => PinStyle.invertedClock,
    'input_low' => PinStyle.inputLow,
    'clock_low' => PinStyle.clockLow,
    'output_low' => PinStyle.outputLow,
    'edge_clock_high' => PinStyle.edgeClockHigh,
    'non_logic' => PinStyle.nonLogic,
    _ => PinStyle.line,
  };

  static FillType parseFillType(String type) => switch (type) {
    'none' => FillType.none,
    'outline' => FillType.outline,
    'background' => FillType.background,
    _ => FillType.none,
  };

  static Justify parseJustify(String justify) => switch (justify) {
    'left' => Justify.left,
    'right' => Justify.right,
    'center' => Justify.center,
    'top' => Justify.top,
    'bottom' => Justify.bottom,
    'top_left' => Justify.topLeft,
    'top_right' => Justify.topRight,
    'bottom_left' => Justify.bottomLeft,
    'bottom_right' => Justify.bottomRight,
    _ => Justify.center,
  };

  static Justify parseJustify2(String justify, String justify2) =>
      switch ([justify, justify2]) {
        ['left', 'bottom'] => Justify.bottomLeft,
        ['right', 'bottom'] => Justify.bottomRight,
        ['center', 'bottom'] => Justify.bottom,
        ['left', 'top'] => Justify.topLeft,
        ['right', 'top'] => Justify.topRight,
        ['center', 'top'] => Justify.top,
        ['left', 'center'] => Justify.left,
        ['right', 'center'] => Justify.right,
        _ => Justify.center,
      };
}
