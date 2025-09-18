import 'package:flutter_test/flutter_test.dart';
import 'package:pcb_rev/features/kicad/data/kicad_symbol_loader.dart';

void main() {
  group('KiCad Symbol Library Tests', () {
    test('KiCad Parser can parse existing project file', () async {
      final loader = KiCadLibrarySymbolLoader(
        'lib/features/symbol_library/data/example_kicad_symbols.kicad_sym',
      );

      // Test parsing the example KiCad symbols file
      final symbols = await loader.loadAllLibrarySymbols();

      expect(symbols, isNotEmpty);

      // Check if we can find specific symbols
      final resistorSymbol = symbols['R'];
      expect(resistorSymbol, isNotNull);
      expect(resistorSymbol!.units, isNotEmpty);
      expect(resistorSymbol.units[1].pins, hasLength(2));

      final capacitorSymbol = symbols['C_Polarized'];
      expect(capacitorSymbol, isNotNull);
      expect(capacitorSymbol!.units, isNotEmpty);
      expect(capacitorSymbol.units[1].pins, hasLength(2));

      final stm32Symbol = symbols['STM32F030C6Tx'];
      expect(stm32Symbol, isNotNull);
      expect(stm32Symbol!.units, isNotEmpty);
      expect(stm32Symbol.units[1].pins.length, greaterThan(40));

      final drv2605Symbol = symbols['DRV2605LDGST'];
      expect(drv2605Symbol, isNotNull);
      expect(drv2605Symbol!.units, isNotEmpty);
      final drvUnit = drv2605Symbol.units.length > 1
          ? drv2605Symbol.units[1]
          : drv2605Symbol.units[0];
      expect(drvUnit.pins, hasLength(9));
    });

    test('KiCad Symbol Loader can load individual symbols', () async {
      final loader = KiCadLibrarySymbolLoader(
        'lib/features/symbol_library/data/example_kicad_symbols.kicad_sym',
      );

      // Test loading a specific symbol
      final symbol = await loader.loadLibrarySymbol('R');
      expect(symbol, isNotNull);
    });
  });
}
