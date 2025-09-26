import 'package:pcb_rev/kicad/data/kicad_symbol_loader.dart';

void main() async {
  final loader = KiCadLibrarySymbolLoader(
    'lib/features/symbol_library/data/example_kicad_symbols.kicad_sym',
  );

  // Test loading all library symbols
  try {
    final symbols = await loader.loadAllLibrarySymbols();
    print('Loaded ${symbols.length} library symbols:');
    for (final entry in symbols.entries) {
      print('  ${entry.key}: ${entry.value.units.length} units');
    }

    // Try to load specific library symbols
    try {
      final rSymbol = await loader.loadLibrarySymbol('R');
      print('Loaded R library symbol with ${rSymbol.units.length} units');
    } catch (e) {
      print('Failed to load R library symbol: $e');
    }

    try {
      final cSymbol = await loader.loadLibrarySymbol('C_Polarized');
      print('Loaded C_Polarized library symbol with ${cSymbol.units.length} units');
    } catch (e) {
      print('Failed to load C_Polarized library symbol: $e');
    }

    try {
      final stm32Symbol = await loader.loadLibrarySymbol('STM32F030C6Tx');
      print(
        'Loaded STM32F030C6Tx library symbol with ${stm32Symbol.units.length} units',
      );
    } catch (e) {
      print('Failed to load STM32F030C6Tx library symbol: $e');
    }
  } catch (e) {
    print('Error loading symbols: $e');
  }
}
