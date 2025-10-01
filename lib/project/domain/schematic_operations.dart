
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../kicad/data/kicad_schematic_models.dart';
import '../../kicad/data/kicad_symbol_loader.dart';
import '../../kicad/api/kicad_schematic_api_impl.dart';
import '../api/application_api.dart';
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart' as kicad_symbol_models;

typedef SchematicResult = ({bool success, KiCadSchematic? schematic, String? path, String? error});
typedef SymbolLoaderResult = ({
  bool success,
  KiCadLibrarySymbolLoader? loader,
  String? error,
});

Future<SchematicResult> loadSchematic(
  ApplicationAPI api,
  String path,
) async {
  try {
    final schematic = await api.loadSchematic(path);
    return (success: true, schematic: schematic, path: path, error: null);
  } catch (e) {
    return (success: false, schematic: null, path: null, error: e.toString());
  }
}

Future<SchematicResult> loadSchematicFromPicker(
  ApplicationAPI api,
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
      return (success: false, schematic: null, path: null, error: 'Invalid file type. Please select a .kicad_sch file.');
    }

    try {
      final schematic = await api.loadSchematic(path);
      return (success: true, schematic: schematic, path: path, error: null);
    } catch (e) {
      return (success: false, schematic: null, path: null, error: e.toString());
    }
  }
  return (success: false, schematic: null, path: null, error: 'Load cancelled.');
}

Future<SymbolLoaderResult> loadDefaultSymbolLibrary(String path) async {
  try {
    final loader = KiCadLibrarySymbolLoader(path);
    await loader.loadAllLibrarySymbols();
    return (success: true, loader: loader, error: null);
  } catch (e) {
    return (success: false, loader: null, error: e.toString());
  }
}
Future<KiCadLibrarySymbolLoader?> loadDefaultSymbolLibrary2() async {
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

Future<KiCadSchematic?> loadDefaultSchematic(ApplicationAPI api) async {
  final defaultSchematicPath = 'test/kiProject1/kiProject1.kicad_sch';
  final file = File(defaultSchematicPath);

  if (await file.exists()) {
    try {
      return await api.loadSchematic(defaultSchematicPath);
    } catch (e) {
      print('Error loading default schematic: $e');
    }
  }
  return null;
}

Future<({bool success, String? error})> saveKiCadSchematic(
  ApplicationAPI api,
  KiCadSchematic? schematic,
  String path,
) async {
  if (schematic == null) {
    return (success: false, error: 'No schematic to save.');
  }


  if (path.isNotEmpty && path.endsWith('.kicad_sch')) {
    try {
      await api.saveKiCadSchematic(schematic, path);
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }
  return (success: false, error: 'Invalid file path.');
}

Future<({bool success, String? error})> saveKiCadSchematicFromPicker(
  ApplicationAPI api,
  KiCadSchematic? schematic,
) async {
  if (schematic == null) {
    return (success: false, error: 'No schematic to save.');
  }

  String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'Please select where to save the schematic:',
    fileName: 'schematic.kicad_sch',
    allowedExtensions: ['kicad_sch'],
  );

  if (outputFile != null) {
    try {
      await api.saveKiCadSchematic(schematic, outputFile);
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }
  return (success: false, error: 'No file selected.');
}


KiCadSchematic? addComponent(
  KiCadSchematicAPIImpl schematicApi,
  Map<String, dynamic> componentData,
  kicad_symbol_models.LibrarySymbol? selectedLibrarySymbol,
  KiCadSchematic? schematic,
  KiCadLibrarySymbolLoader? symbolLoader,
) {
  if (schematic == null || symbolLoader == null) {
    return null;
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
    return null;
  }

  if (reference.isNotEmpty && schematic.symbolInstances.any((inst) =>
      inst.properties.any((prop) =>
          prop.name == 'Reference' && prop.value == reference))) {
    return null;
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
  final newRef = reference.isNotEmpty ? reference : schematicApi.generateNewRef(schematic, prefix);

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

  return schematic.copyWith(symbolInstances: updatedInstances);
}

KiCadSchematic? addSymbolInstance(
  KiCadSchematicAPIImpl schematicApi,
  kicad_symbol_models.LibrarySymbol? selectedLibrarySymbol,
  SymbolInstance? selectedSymbolInstance,
  KiCadSchematic? schematic,
  KiCadLibrarySymbolLoader? symbolLoader,
) {
  if (schematic == null || symbolLoader == null) {
    return null;
  }

  kicad_symbol_models.LibrarySymbol? librarySymbol = selectedLibrarySymbol;
  librarySymbol ??= schematicApi.resolveLibrarySymbol(
    symbolId: selectedSymbolInstance?.libId ?? '',
    symbolLoader: symbolLoader,
    schematic: schematic,
  );

  if (librarySymbol == null) {
    return null;
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

  return schematicApi.addSymbolInstance(
    schematic: schematic,
    libId: librarySymbol.name,
    reference: schematicApi.generateNewRef(schematic, prefix),
    value: propertyValue.value,
    position: kicad_symbol_models.Position(150, 100),
  );
}
