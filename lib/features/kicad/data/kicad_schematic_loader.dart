import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../domain/kicad_schematic_parser.dart';
import 'kicad_schematic_models.dart';
import '../../../debug/log_service.dart';

/// Service for loading KiCad schematic files.
class KiCadSchematicLoader {
  final String? schematicPath;
  final String? _content;

  KiCadSchematicLoader(this.schematicPath) : _content = null;

  KiCadSchematicLoader.fromContent(String content)
      : schematicPath = null,
        _content = content;

  /// Load the KiCad schematic file.
  Future<KiCadSchematic> load() async {
    try {
      String content;

      if (_content != null) {
        content = _content!;
        LogService.instance.info('Parsing schematic from content...');
      } else if (schematicPath != null && !kIsWeb) {
        LogService.instance.info('Loading schematic from: $schematicPath');
        final file = File(schematicPath!);
        if (!file.existsSync()) {
          throw Exception('Schematic file not found at: $schematicPath');
        }
        content = await file.readAsString();
      } else {
        throw Exception('No schematic path or content provided');
      }

      LogService.instance.info('Parsing schematic...');
      final parseResult = KiCadSchematicParser.parse(content);

      return parseResult.fold(
        (schematic) {
          LogService.instance.success('Schematic loaded successfully');
          return schematic;
        },
        (error) {
          LogService.instance.error('Failed to parse schematic: $error');
          throw Exception('Failed to parse KiCad schematic: $error');
        },
      );
    } catch (e) {
      LogService.instance.error('Error loading schematic: $e');
      throw Exception('Error loading KiCad schematic: $e');
    }
  }
}
