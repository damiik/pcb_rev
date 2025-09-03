import 'package:pcb_rev/features/symbol_library/data/kicad_symbol_loader.dart';
import 'package:pcb_rev/features/symbol_library/domain/kicad_symbol_parser.dart';
import 'dart:io';

void main() async {
  final file = File(
    'lib/features/symbol_library/data/example_kicad_symbols.kicad_sym',
  );
  final content = await file.readAsString();

  // Parse directly to see details
  final libraryResult = KiCadParser.parseLibrary(content);

  libraryResult.fold(
    (library) {
      print('Library parsed successfully:');
      print('  Version: ${library.version}');
      print('  Generator: ${library.generator}');
      print('  Symbols count: ${library.librarySymbols.length}');

      for (final symbol in library.librarySymbols) {
        print('  Symbol: ${symbol.name}');
        print('    Properties: ${symbol.properties.length}');
        for (final prop in symbol.properties) {
          print('      - ${prop.name}: ${prop.value}');
        }
        print('    Units: ${symbol.units.length}');
        for (final unit in symbol.units) {
          print('      Unit: ${unit.name}');
          print('        Graphics: ${unit.graphics.length}');
          print('        Pins: ${unit.pins.length}');
          for (final pin in unit.pins) {
            print('          - Pin ${pin.number}: ${pin.name} (${pin.type})');
          }
        }
      }
    },
    (error) {
      print('Library parse error: $error');
    },
  );

  print('\n=== LOADER TEST ===');
  final loader = KiCadLibrarySymbolLoader(
    'lib/features/symbol_library/data/example_kicad_symbols.kicad_sym',
  );

  try {
    final symbols = await loader.loadAllLibrarySymbols();
    print('Loaded ${symbols.length} symbols:');

    final rSymbol = symbols['R'];
    if (rSymbol != null) {
      print('R symbol:');
      print('  Units: ${rSymbol.units.length}');
      for (final unit in rSymbol.units) {
        print('    Unit: ${unit.name}');
        print('      Pins: ${unit.pins.length}');
        for (final pin in unit.pins) {
          print('        - Pin ${pin.number}: ${pin.name} (${pin.type})');
        }
      }
    }

    final cSymbol = symbols['C_Polarized'];
    if (cSymbol != null) {
      print('C_Polarized symbol:');
      print('  Units: ${cSymbol.units.length}');
      for (final unit in cSymbol.units) {
        print('    Unit: ${unit.name}');
        print('      Pins: ${unit.pins.length}');
        for (final pin in unit.pins) {
          print('        - Pin ${pin.number}: ${pin.name} (${pin.type})');
        }
      }
    }
  } catch (e) {
    print('Error loading symbols: $e');
  }
}
