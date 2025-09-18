import 'package:flutter_test/flutter_test.dart';
import 'package:pcb_rev/features/kicad/data/kicad_schematic_loader.dart';
import 'package:pcb_rev/features/kicad/data/kicad_schematic_models.dart';

void main() {
  test('KiCad Schematic Parser Test', () async {
    // Path to the test schematic file
    final path = 'test/kiProject1/kiProject1.kicad_sch';

    // Create a loader for the schematic
    final loader = KiCadSchematicLoader(path);

    // Load and parse the schematic
    final KiCadSchematic schematic = await loader.load();

    // Verification
    expect(schematic, isNotNull);
    expect(schematic.symbolInstances.length, 10);
    expect(schematic.wires.length, 23);
    expect(schematic.junctions.length, 7);

    print('Successfully parsed schematic:');
    print('  - Symbol Instances: ${schematic.symbolInstances.length}');
    print('  - Wires: ${schematic.wires.length}');
    print('  - Junctions: ${schematic.junctions.length}');

    // Optional: Check a specific property of a symbol
    final r1 = schematic.symbolInstances.firstWhere((s) => s.properties.any((p) => p.name == 'Reference' && p.value == 'R1'));
    expect(r1.libId, 'Device:R');
  });
}
