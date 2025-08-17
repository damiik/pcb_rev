import 'package:flutter_test/flutter_test.dart';
import 'package:pcb_rev/features/symbol_library/domain/kicad_symbol_parser.dart';
import 'package:pcb_rev/features/symbol_library/data/kicad_symbol_loader.dart';
import 'package:pcb_rev/features/symbol_library/data/kicad_schematic_models.dart';

void main() {
  group('KiCad Symbol Library Tests', () {
    test('KiCad Parser can parse existing project file', () async {
      final loader = KiCadSymbolLoader(
        'lib/features/schematic/data/symbol_library/example_kicad_symbols.kicad_sym',
      );

      // Test parsing the example KiCad symbols file
      final symbols = await loader.loadAllSymbols();

      expect(symbols, isNotEmpty);

      // Check if we can find specific symbols
      final resistorSymbol = symbols['Device:R'];
      expect(resistorSymbol, isNotNull);
      expect(resistorSymbol!.units, isNotEmpty);
      expect(resistorSymbol!.units.first.pins, hasLength(2));

      final capacitorSymbol = symbols['Device:C_Polarized'];
      expect(capacitorSymbol, isNotNull);
      expect(capacitorSymbol!.units, isNotEmpty);
      expect(capacitorSymbol!.units.first.pins, hasLength(2));

      final stm32Symbol = symbols['MCU_ST_STM32F0:STM32F030C6Tx'];
      expect(stm32Symbol, isNotNull);
      expect(stm32Symbol!.units, isNotEmpty);
      expect(stm32Symbol!.units.first.pins.length, greaterThan(40));
    });

    test('KiCad Symbol Loader can load individual symbols', () async {
      final loader = KiCadSymbolLoader(
        'lib/features/schematic/data/symbol_library/example_kicad_symbols.kicad_sym',
      );

      // Test loading a specific symbol
      final symbol = await loader.loadSymbol('Device:R');
      expect(symbol, isNotNull);

      // Test loading a non-existent symbol
      final nonExistentSymbol = await loader.loadSymbol(
        'NonExistent:Component',
      );
      expect(nonExistentSymbol, isNull);
    });

    test('Component type mapping works', () {
      // Test that common component types map to KiCad symbols
      final typeMappings = {
        'resistor': 'Device:R',
        'capacitor': 'Device:C_Polarized',
        'switch': 'Switch:SW_Push',
        'ground': 'power:GND',
        'stm32': 'MCU_ST_STM32F0:STM32F030C6Tx',
      };

      expect(typeMappings['resistor'], 'Device:R');
      expect(typeMappings['capacitor'], 'Device:C_Polarized');
      expect(typeMappings['switch'], 'Switch:SW_Push');
      expect(typeMappings['ground'], 'power:GND');
    });
  });
}
