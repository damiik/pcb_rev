import 'dart:io';
import '../domain/kicad_schematic_parser.dart';
import 'kicad_schematic_models.dart';

/// Service for loading KiCad schematic files.
class KiCadSchematicLoader {
  final String schematicPath;

  KiCadSchematicLoader(this.schematicPath);

  /// Load the KiCad schematic file.
  Future<KiCadSchematic> load() async {
    try {
      final file = File(schematicPath);
      if (!file.existsSync()) {
        throw Exception('Schematic file not found at: $schematicPath');
      }

      final content = await file.readAsString();
      final parseResult = KiCadSchematicParser.parse(content);

      return parseResult.fold(
        (schematic) => schematic,
        (error) => throw Exception('Failed to parse KiCad schematic: $error'),
      );
    } catch (e) {
      throw Exception('Error loading KiCad schematic: $e');
    }
  }
}
