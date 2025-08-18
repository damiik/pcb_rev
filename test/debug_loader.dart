import 'package:pcb_rev/features/symbol_library/data/kicad_symbol_loader.dart';

void main() async {
  final loader = KiCadSymbolLoader(
    'lib/features/symbol_library/data/example_kicad_symbols.kicad_sym',
  );

  // Test loading all symbols
  try {
    final symbols = await loader.loadAllSymbols();
    print('Loaded ${symbols.length} symbols:');
    for (final entry in symbols.entries) {
      print('  ${entry.key}: ${entry.value.units.length} units');
    }

    // Try to load specific symbols
    try {
      final rSymbol = await loader.loadSymbol('R');
      print('Loaded R symbol with ${rSymbol.units.length} units');
    } catch (e) {
      print('Failed to load R symbol: $e');
    }

    try {
      final cSymbol = await loader.loadSymbol('C_Polarized');
      print('Loaded C_Polarized symbol with ${cSymbol.units.length} units');
    } catch (e) {
      print('Failed to load C_Polarized symbol: $e');
    }

    try {
      final stm32Symbol = await loader.loadSymbol('STM32F030C6Tx');
      print(
        'Loaded STM32F030C6Tx symbol with ${stm32Symbol.units.length} units',
      );
    } catch (e) {
      print('Failed to load STM32F030C6Tx symbol: $e');
    }
  } catch (e) {
    print('Error loading symbols: $e');
  }
}
