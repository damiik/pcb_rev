import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../kicad/data/kicad_schematic_models.dart';
import '../../kicad/data/kicad_symbol_loader.dart';
import '../../kicad/api/kicad_schematic_api_impl.dart';
import '../api/application_api.dart';
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart' as kicad_symbol_models;

/// Manages schematic-related operations like loading, saving, and updating schematics
class SchematicManager {
  final ApplicationAPI _applicationAPI;
  final KiCadSchematicAPIImpl _schematicApi;

  SchematicManager(this._applicationAPI, this._schematicApi);

  /// Load schematic from file picker
  Future<KiCadSchematic?> loadSchematic(
    BuildContext context,
    Function(KiCadSchematic, String) onSuccess,
    VoidCallback onError,
  ) async {
    FilePickerResult? result;
    if (!kIsWeb && Platform.isLinux) {
      result = await FilePicker.platform.pickFiles(type: FileType.any);
    } else {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kicad_sch'],
      );
    }

    if (result != null) {
      final path = result.files.single.path!;
      if (Platform.isLinux && !path.endsWith('.kicad_sch')) {
        _showErrorSnackBar(context, 'Invalid file type. Please select a .kicad_sch file.');
        return null;
      }

      try {
        final schematic = await _applicationAPI.loadSchematic(path);
        onSuccess(schematic, path);
        return schematic;
      } catch (e) {
        print('Error loading schematic file: $e');
        _showErrorSnackBar(context, 'Error loading schematic: $e');
        onError();
      }
    }
    return null;
  }

  /// Load default symbol library
  Future<KiCadLibrarySymbolLoader?> loadDefaultSymbolLibrary() async {
    try {
      final libraryPath = 'test/kiProject1/example_kicad_symbols.kicad_sym';
      final loader = KiCadLibrarySymbolLoader(libraryPath);
      await loader.loadAllLibrarySymbols();
      return loader;
    } catch (e) {
      print('Error loading default symbol library: $e');
      return null;
    }
  }

  /// Load default schematic
  Future<KiCadSchematic?> loadDefaultSchematic() async {
    final defaultSchematicPath = 'test/kiProject1/kiProject1.kicad_sch';
    final file = File(defaultSchematicPath);

    if (await file.exists()) {
      try {
        return await _applicationAPI.loadSchematic(defaultSchematicPath);
      } catch (e) {
        print('Error loading default schematic: $e');
      }
    }
    return null;
  }

  /// Save KiCad schematic to file
  Future<void> saveKiCadSchematic(
    KiCadSchematic? schematic,
    BuildContext context,
    VoidCallback onSuccess,
    VoidCallback onError,
  ) async {
    if (schematic == null) {
      _showErrorSnackBar(context, 'No schematic loaded to save.');
      return;
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select where to save the schematic:',
      fileName: 'schematic.kicad_sch',
      allowedExtensions: ['kicad_sch'],
    );

    if (outputFile != null) {
      try {
        await _applicationAPI.saveKiCadSchematic(schematic, outputFile);
        onSuccess();
      } catch (e) {
        _showErrorSnackBar(context, 'Error saving schematic: $e');
        onError();
      }
    }
  }

  /// Add a component to the schematic
  void addComponent(
    Map<String, dynamic> componentData,
    kicad_symbol_models.LibrarySymbol? selectedLibrarySymbol,
    KiCadSchematic? schematic,
    KiCadLibrarySymbolLoader? symbolLoader,
    BuildContext context,
    Function(KiCadSchematic) onSchematicUpdated,
  ) {
    if (schematic == null || symbolLoader == null) {
      _showErrorSnackBar(context, "Schematic or symbol library not loaded.");
      return;
    }

    final String type = componentData['type'];
    final String value = componentData['value'];
    final String reference = componentData['name'];

    kicad_symbol_models.LibrarySymbol? librarySymbol = selectedLibrarySymbol;
    if (librarySymbol == null && schematic.library?.librarySymbols != null) {
      final libSymbols = schematic.library!.librarySymbols;
      final matches = libSymbols.where((s) => s.name == type);
      if (matches.isNotEmpty) {
        librarySymbol = matches.first;
      }
    }

    if (librarySymbol == null) {
      _showErrorSnackBar(context, "Symbol '$type' not found in library.");
      return;
    }

    // Check if reference is unique
    if (reference.isNotEmpty && schematic.symbolInstances.any((inst) =>
        inst.properties.any((prop) =>
            prop.name == 'Reference' && prop.value == reference))) {
      _showErrorSnackBar(context, "Component with reference '$reference' already exists.");
      return;
    }

    kicad_symbol_models.Property? maybeProperty;
    try {
      maybeProperty = librarySymbol.properties.firstWhere(
        (p) => p.name == 'Reference',
      );
    } catch (e) {
      maybeProperty = null;
    }
    final prefix = maybeProperty?.value.replaceAll(RegExp(r'\d'), '') ?? 'X';
    final newRef = reference.isNotEmpty ? reference : _schematicApi.generateNewRef(schematic, prefix);

    final newSymbolInstance = SymbolInstance(
      libId: librarySymbol.name,
      at: const kicad_symbol_models.Position(150, 100),
      uuid: Uuid().v4(),
      unit: 1,
      inBom: true,
      onBoard: true,
      dnp: false,
      properties: [
        kicad_symbol_models.Property(name: 'Reference', value: newRef, position: const kicad_symbol_models.Position(0, 0), effects: const kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1.27, height: 1.27), justify: kicad_symbol_models.Justify.left, hide: false)),
        kicad_symbol_models.Property(name: 'Value', value: value, position: const kicad_symbol_models.Position(0, 0), effects: const kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1.27, height: 1.27), justify: kicad_symbol_models.Justify.left, hide: false)),
        kicad_symbol_models.Property(name: 'Footprint', value: "", position: const kicad_symbol_models.Position(0, 0), effects: const kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1.27, height: 1.27), justify: kicad_symbol_models.Justify.left, hide: true)),
        kicad_symbol_models.Property(name: 'Datasheet', value: "", position: const kicad_symbol_models.Position(0, 0), effects: const kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1.27, height: 1.27), justify: kicad_symbol_models.Justify.left, hide: true)),
      ],
    );

    final updatedInstances = List<SymbolInstance>.from(schematic.symbolInstances)
      ..add(newSymbolInstance);

    final updatedSchematic = schematic.copyWith(symbolInstances: updatedInstances);
    onSchematicUpdated(updatedSchematic);
  }

  /// Add a symbol instance to the schematic
  void addSymbolInstance(
    kicad_symbol_models.LibrarySymbol? selectedLibrarySymbol,
    SymbolInstance? selectedSymbolInstance,
    KiCadSchematic? schematic,
    KiCadLibrarySymbolLoader? symbolLoader,
    BuildContext context,
    Function(KiCadSchematic) onSchematicUpdated,
  ) {
    if (schematic == null || symbolLoader == null) {
      _showErrorSnackBar(context, "Schematic or symbol library not loaded.");
      return;
    }

    kicad_symbol_models.LibrarySymbol? librarySymbol = selectedLibrarySymbol;
    librarySymbol ??= _schematicApi.resolveLibrarySymbol(
      symbolId: selectedSymbolInstance?.libId ?? '',
      symbolLoader: symbolLoader,
      schematic: schematic,
    );

    if (librarySymbol == null) {
      _showErrorSnackBar(context, "Symbol not found. You have to select a symbol from the library list first.");
      return;
    }

    kicad_symbol_models.Property? maybeProperty;
    try {
      maybeProperty = librarySymbol.properties.firstWhere(
        (p) => p.name == 'Reference',
      );
    } catch (e) {
      maybeProperty = null;
    }
    final prefix = maybeProperty?.value.replaceAll(RegExp(r'\d'), '') ?? 'X';

    kicad_symbol_models.Property propertyValue = librarySymbol.properties.firstWhere(
      (p) => p.name == 'Value',
      orElse: () => kicad_symbol_models.Property(name: 'Value', value: '', position: kicad_symbol_models.Position(0, 0), effects: kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1, height: 1), justify: kicad_symbol_models.Justify.left, hide: false))
    );

    final updatedSchematic = _schematicApi.addSymbolInstance(
      schematic: schematic,
      libId: librarySymbol.name,
      reference: _schematicApi.generateNewRef(schematic, prefix),
      value: propertyValue.value,
      position: kicad_symbol_models.Position(150, 100),
    );

    onSchematicUpdated(updatedSchematic);
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
}
