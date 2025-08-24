import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_models.dart';
import 'kicad_tokenizer.dart';
import 'kicad_sexpr_parser.dart';
import 'kicad_symbol_parser.dart';

/// Parser for .kicad_sch files.
final class KiCadSchematicParser {
  /// Parses the full content of a .kicad_sch file.
  static ParseResult<KiCadSchematic> parse(String content) {
    final tokenizer = Tokenizer(content);
    final tokens = tokenizer.tokenize();
    final sexprParser = SExprParser(tokens);

    return sexprParser.parse().fold(
      (sexprs) => _parseSchematicFromSExprs(sexprs),
      (error) => ParseResult.failure(error),
    );
  }

  static ParseResult<KiCadSchematic> _parseSchematicFromSExprs(
    List<SExpr> sexprs,
  ) {
    try {
      final schematicExpr =
          sexprs.firstWhere(
                (expr) =>
                    expr is SList &&
                    expr.elements.isNotEmpty &&
                    (expr.elements.first as SAtom).value == 'kicad_sch',
                orElse: () =>
                    throw Exception('No kicad_sch root element found'),
              )
              as SList;

      return ParseResult.success(_parseSchematicExpr(schematicExpr));
    } catch (e) {
      return ParseResult.failure('Schematic parsing error: $e');
    }
  }

  static KiCadSchematic _parseSchematicExpr(SList expr) {
    var version = '';
    var generator = '';
    var uuid = '';
    KiCadLibrary? library;
    final symbols = <SymbolInstance>[];
    final wires = <Wire>[];
    final junctions = <Junction>[];

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
          elements: [SAtom(value: 'uuid'), SAtom(value: final u), ...],
        ):
          uuid = u;

        case SList(
          elements: [SAtom(value: 'lib_symbols'), ...final libElements],
        ):
          library = KiCadParser.parseLibraryExpr(
            SList([SAtom('kicad_symbol_lib'), ...libElements]),
          );

        case SList(elements: [SAtom(value: 'symbol'), ...final symbolElements]):
          symbols.add(_parseSymbolInstance(symbolElements));
          break;

        case SList(elements: [SAtom(value: 'wire'), ...final wireElements]):
          wires.add(_parseWire(wireElements));
          break;

        case SList(
          elements: [SAtom(value: 'junction'), ...final junctionElements],
        ):
          junctions.add(_parseJunction(junctionElements));
          break;

        default:
          break;
      }
    }

    return KiCadSchematic(
      version: version,
      generator: generator,
      uuid: uuid,
      library: library,
      symbols: symbols,
      wires: wires,
      junctions: junctions,
    );
  }

  static SymbolInstance _parseSymbolInstance(List<SExpr> elements) {
    String libId = '';
    Position at = Position(0, 0, 0);
    String uuid = '';
    List<Property> properties = [];
    int unit = 1;
    bool inBom = true;
    bool onBoard = true;
    bool dnp = false;
    bool mirrorx = false;
    bool mirrory = false;

    for (final element in elements) {
      switch (element) {
        case SList(
          elements: [SAtom(value: 'lib_id'), SAtom(value: final id), ...],
        ):
          libId = id;
        case SList(
          elements: [
            SAtom(value: 'at'),
            SAtom(value: final x),
            SAtom(value: final y),
            SAtom(value: final angle),
            ...,
          ],
        ):
          at = Position(double.parse(x), double.parse(y), double.parse(angle));
        case SList(
          elements: [SAtom(value: 'uuid'), SAtom(value: final u), ...],
        ):
          uuid = u;
        case SList(elements: [SAtom(value: 'property'), ...final propElements]):
          properties.add(KiCadParser.parseProperty(propElements));
        case SList(
          elements: [SAtom(value: 'unit'), SAtom(value: final u), ...],
        ):
          unit = int.parse(u);
        case SList(
          elements: [SAtom(value: 'in_bom'), SAtom(value: final v), ...],
        ):
          inBom = v == 'yes';
        case SList(
          elements: [SAtom(value: 'on_board'), SAtom(value: final v), ...],
        ):
          onBoard = v == 'yes';
        case SList(elements: [SAtom(value: 'dnp'), SAtom(value: final v), ...]):
          dnp = v == 'yes';
        case SList(elements: [SAtom(value: 'mirror'), SAtom(value: 'x'), ...]):
          mirrorx = true;
        case SList(elements: [SAtom(value: 'mirror'), SAtom(value: 'y'), ...]):
          mirrory = true;
        default:
          break;
      }
    }
    print('Parsed symbol instance: $libId at $at with uuid $uuid');

    return SymbolInstance(
      libId: libId,
      at: at,
      uuid: uuid,
      properties: properties,
      unit: unit,
      inBom: inBom,
      onBoard: onBoard,
      dnp: dnp,
      mirrorx: mirrorx,
      mirrory: mirrory,
    );
  }

  static Wire _parseWire(List<SExpr> elements) {
    // print('Parsing wire with elements: $elements');
    List<Position> pts = [];
    String uuid = '';
    Stroke stroke = Stroke(width: 0);

    for (final element in elements) {
      switch (element) {
        case SList(elements: [SAtom(value: 'pts'), ...final ptElements]):
          for (final ptExpr in ptElements) {
            if (ptExpr case SList(
              elements: [
                SAtom(value: 'xy'),
                SAtom(value: final x),
                SAtom(value: final y),
              ],
            )) {
              pts.add(Position(double.parse(x), double.parse(y)));
            }
          }
        case SList(
          elements: [SAtom(value: 'uuid'), SAtom(value: final u), ...],
        ):
          uuid = u;
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
        default:
          break;
      }
    }
    // print('Parsed wire with points: $pts');
    return Wire(pts: pts, uuid: uuid, stroke: stroke);
  }

  static Junction _parseJunction(List<SExpr> elements) {
    Position at = Position(0, 0);
    String uuid = '';
    double diameter = 0;

    for (final element in elements) {
      switch (element) {
        case SList(
          elements: [
            SAtom(value: 'at'),
            SAtom(value: final x),
            SAtom(value: final y),
            ...,
          ],
        ):
          at = Position(double.parse(x), double.parse(y));
        case SList(
          elements: [SAtom(value: 'uuid'), SAtom(value: final u), ...],
        ):
          uuid = u;
        case SList(
          elements: [SAtom(value: 'diameter'), SAtom(value: final d), ...],
        ):
          diameter = double.parse(d);
        default:
          break;
      }
    }

    return Junction(at: at, uuid: uuid, diameter: diameter);
  }
}
