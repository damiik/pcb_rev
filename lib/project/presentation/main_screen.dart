import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show IntProperty, kIsWeb;
import 'package:flutter/material.dart';
import '../../measurement/data/measurement_service.dart'
    as measurement_service;
import '../../pcb_viewer/data/image_modification.dart';
import '../../pcb_viewer/presentation/pcb_viewer_panel.dart';
import '../data/logical_models.dart';
import '../../global_list/presentation/widgets/global_list_panel.dart';
import '../../measurement/presentation/properties_panel.dart';
import '../data/project.dart';
import 'package:pcb_rev/pcb_viewer/data/image_processor.dart'
    as image_processor;
import 'package:pcb_rev/features/kicad/data/kicad_symbol_models.dart';
import '../../features/kicad/data/kicad_schematic_models.dart';
import '../../features/kicad/data/kicad_schematic_loader.dart';
import '../../features/kicad/data/kicad_symbol_loader.dart';
import 'package:pcb_rev/features/kicad/data/kicad_symbol_models.dart'
    as kicad_symbol_models;
import '../../features/kicad/presentation/schematic_view.dart';
import '../../features/kicad/domain/kicad_schematic_writer.dart';
import '../../features/ai_integration/data/mcp_server.dart';
import '../../features/ai_integration/data/mcp_server_ext.dart';

import 'package:pcb_rev/features/connectivity/models/core.dart' as connectivity_core;
import '../../features/connectivity/domain/connectivity_adapter.dart';
import '../../features/connectivity/models/connectivity.dart';
import '../../features/connectivity/api/netlist_api.dart' as netlist_api;
import '../api/schematic_api.dart';


enum ViewMode { pcb, schematic }

class PCBAnalyzerApp extends StatefulWidget {
  const PCBAnalyzerApp({Key? key}) : super(key: key);

  @override
  _PCBAnalyzerAppState createState() => _PCBAnalyzerAppState();
}

class _PCBAnalyzerAppState extends State<PCBAnalyzerApp> {

  final _schematicAPI = KiCadSchematicAPI();
  MCPServer? _mcpServer;
  ViewMode _currentView = ViewMode.pcb;
  Project? currentProject;
  int _currentImageIndex = 0;
  LogicalComponent? _draggingComponent;
  bool _isProcessingImage = false;
  measurement_service.MeasurementState measurementState =
      measurement_service.createInitialMeasurementState();
  bool _dragging = false;
  KiCadSchematic? _loadedSchematic;
  KiCadLibrarySymbolLoader? _symbolLoader;
  kicad_symbol_models.Position? _centerOnPosition;
  String? _selectedSymbolInstanceId;
  SymbolInstance? _selectedSymbolInstance;
  kicad_symbol_models.LibrarySymbol? _selectedLibrarySymbol;
  Connectivity? _connectivity;
  connectivity_core.Net? _selectedNet;

  @override
  void initState() {
    super.initState();
    print('Initializing PCB Analyzer App...');
    _initializeServer();
    _initializeProject();
    _loadDefaultSymbolLibrary();
  }

  void _initializeServer() {
    _mcpServer = MCPServer(
      getSchematic: () => _loadedSchematic,
      updateSchematic: (newSchematic) {
        setState(() {
          _loadedSchematic = newSchematic;
        });
        _updateConnectivity();
      },
      getSymbolLibraries: () {
        final List<KiCadLibrary> libs = [];
        if (_symbolLoader != null) {
          // This is a simplification. In a real app, you'd manage a list of loaders.
        }
        if (_loadedSchematic?.library != null) {
          libs.add(_loadedSchematic!.library!);
        }
        return libs;
      },
      getConnectivity: () => _connectivity,
    );
    _mcpServer!.registerToolHandlers(_mcpServer!.extendedToolHandlers);
    _mcpServer!.registerToolDefinitions(_mcpServer!.extendedToolDefinitions);
    _mcpServer!.start();
  }

  void _initializeProject() {
    setState(() {
      currentProject = projectFromJson({
        'id': '1',
        'name': 'New Project',
        'lastUpdated': DateTime.now().toIso8601String(),
        'logicalComponents': <String, dynamic>{},
        'logicalNets': <String, dynamic>{},
        'schematicFilePath': null, // No schematic loaded initially
        'pcbImages': <dynamic>[],
      });
    });
  }

  void _loadDefaultSymbolLibrary() async {
    try {
      final libraryPath = 'test/kiProject1/example_kicad_symbols.kicad_sym';
      final loader = KiCadLibrarySymbolLoader(libraryPath);
      await loader.loadAllLibrarySymbols(); // Pre-load symbols
      setState(() {
        _symbolLoader = loader;
      });

      // Try to load the default schematic
      _loadDefaultSchematic();
    } catch (e) {
      print('Error loading default symbol library: $e');
    }
  }

  Future<void> _loadDefaultSchematic() async {
    final defaultSchematicPath = 'test/kiProject1/kiProject1.kicad_sch';
    final file = File(defaultSchematicPath);

    if (await file.exists()) {
      await _loadSchematicFile(defaultSchematicPath);
    }
  }

  void _updateConnectivity() {
    if (_loadedSchematic != null && _symbolLoader != null) {
      // Combine symbols from the schematic's library and the external loader
      final allSymbols = <kicad_symbol_models.LibrarySymbol>[];
      if (_loadedSchematic!.library != null) {
        allSymbols.addAll(_loadedSchematic!.library!.librarySymbols);
      }
      allSymbols.addAll(_symbolLoader!.getSymbols());

      // Create a new library with all symbols, removing duplicates
      final uniqueSymbols = <kicad_symbol_models.LibrarySymbol>[];
      final seenNames = <String>{};
      for (final symbol in allSymbols) {
        if (seenNames.add(symbol.name)) {
          uniqueSymbols.add(symbol);
        }
      }

      final completeLibrary = kicad_symbol_models.KiCadLibrary(
        version: _loadedSchematic?.version ?? '20210101',
        generator: _loadedSchematic?.generator ?? 'pcb_rev',
        librarySymbols: uniqueSymbols,
      );

      final connectivity = ConnectivityAdapter.fromSchematic(
        _loadedSchematic!,
        completeLibrary,
      );
      setState(() {
        _connectivity = connectivity;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) {
        _handleImageDrop(detail.files.map((f) => f.path).toList());
      },
      onDragEntered: (detail) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (detail) {
        setState(() {
          _dragging = false;
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(currentProject?.name ?? 'PCB Analyzer'),
          actions: [
            ToggleButtons(
              isSelected: [
                _currentView == ViewMode.pcb,
                _currentView == ViewMode.schematic,
              ],
              onPressed: (index) {
                setState(() {
                  _currentView =
                      index == 0 ? ViewMode.pcb : ViewMode.schematic;
                });
              },
              children: [Icon(Icons.image), Icon(Icons.schema)],
            ),
            SizedBox(width: 20),
            IconButton(
              icon: Icon(Icons.description),
              onPressed: _loadSchematic,
              tooltip: 'Load KiCad Schematic',
            ),
            IconButton(
              icon: Icon(Icons.folder_open),
              onPressed: _openProject,
            ),
            IconButton(icon: Icon(Icons.save), onPressed: _saveProject),
            IconButton(
              icon: Icon(Icons.save_as),
              onPressed: _saveKiCadSchematic,
              tooltip: 'Save KiCad Schematic',
            ),
            IconButton(icon: Icon(Icons.share), onPressed: _exportNetlist),
          ],
        ),
        body: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: GlobalListPanel(
                    components:
                        currentProject?.logicalComponents.values.toList() ??
                            [],
                    nets: _connectivity?.nets ?? [],
                    onComponentSelected: _selectComponent,
                    onNetSelected: (net) {
                      setState(() {
                        _selectedNet = net;
                        _selectedSymbolInstance = null; // Clear other selections
                        _selectedSymbolInstanceId = null;
                      });
                    },
                    schematic: _loadedSchematic,
                    onLibrarySymbolSelected: _selectLibrarySymbol,
                  ),
                ),
                Expanded(flex: 5, child: _buildMainPanel()),
                Expanded(
                  flex: 1,
                  child: PropertiesPanel(  // create child PropertiesPanel with required callbacks  
                    selectedSymbolInstance: _selectedSymbolInstance,
                    selectedNet: _selectedNet,
                    measurementState: measurementState,
                    onMeasurementAdded: _addMeasurement,
                    onComponentAdded: _addComponent,
                    onAddSymbolInstance: _addSymbolInstance,
                    onPropertyUpdated: _updateSymbolProperty,
                  ),
                ),
              ],
            ),
            if (_dragging)
              Container(
                color: Colors.blue.withOpacity(0.2),
                child: Center(
                  child: Icon(
                    Icons.add_photo_alternate,
                    color: Colors.white,
                    size: 100,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPanel() {
    switch (_currentView) {
      case ViewMode.schematic:
        if (_loadedSchematic != null) {
          return SchematicView(
            schematic: _loadedSchematic!,
            centerOn: _centerOnPosition,
            selectedSymbolInstanceId: _selectedSymbolInstanceId,
            onSymbolInstanceSelected: (symbolInstance) {
              setState(() {
                _selectedSymbolInstance = symbolInstance;
                _selectedSymbolInstanceId = symbolInstance.uuid;
              });
            },
          );
        } else {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No schematic loaded.'),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _loadSchematic,
                  child: Text('Load KiCad Schematic'),
                ),
              ],
            ),
          );
        }
      case ViewMode.pcb:
      default:
        return PCBViewerPanel(
          project: currentProject,
          isProcessingImage: _isProcessingImage,
          draggingComponent: _draggingComponent,
          currentIndex: _currentImageIndex,
          onImageDrop: _handleImageDrop,
          onNext: () => _navigateImages(1),
          onPrevious: () => _navigateImages(-1),
          onImageModification: _updateImageModification,
          onTap: _handleTap,
          symbolLoader: _symbolLoader,
        );
    }
  }

  Future<void> _loadSchematic() async {
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Invalid file type. Please select a .kicad_sch file.',
                ),
              ),
            );
          }
        });
        return;
      }
      await _loadSchematicFile(path, switchToView: true);
    }
  }

  Future<void> _loadSchematicFile(
    String path, {
    bool switchToView = false,
  }) async {
    final loader = KiCadSchematicLoader(path);
    try {
      final schematic = await loader.load();
      setState(() {
        _loadedSchematic = schematic;
        if (switchToView) {
          _currentView = ViewMode.schematic;
        }
        if (currentProject != null) {
          currentProject = currentProject!.copyWith(schematicFilePath: path);
        }
        _updateConnectivity();
      });
    } catch (e) {
      print('Error loading schematic file: $e');
    }
  }

  void _navigateImages(int delta) {
    if (currentProject == null) return;
    final newIndex = _currentImageIndex + delta;
    if (newIndex >= 0 && newIndex < currentProject!.pcbImages.length) {
      setState(() => _currentImageIndex = newIndex);
    }
  }

  void _selectComponent(LogicalComponent component) {
    if (_loadedSchematic == null) return;

    SymbolInstance? foundSymbolInstance;
    for (final symbolInstance in _loadedSchematic!.symbolInstances) {
      final reference = _getPropertyValue(symbolInstance.properties, 'Reference');
      if (reference == component.id) {
        foundSymbolInstance = symbolInstance;
        break;
      }
    }

    if (foundSymbolInstance != null) {
      final nonNullableSymbol = foundSymbolInstance;
      kicad_symbol_models.LibrarySymbol? librarySymbol;
      try {
        librarySymbol = _loadedSchematic?.library?.librarySymbols
            .firstWhere((s) => s.name == nonNullableSymbol.libId);
      } catch (e) {
        librarySymbol = null; // Symbol not found
      }

      setState(() {
        _selectedSymbolInstance = nonNullableSymbol;
        _selectedLibrarySymbol = librarySymbol;
        _centerOnPosition = nonNullableSymbol.at;
        _selectedSymbolInstanceId = nonNullableSymbol.uuid;
        _currentView = ViewMode.schematic;
      });
    }
  }

  void _selectLibrarySymbol(kicad_symbol_models.LibrarySymbol symbol) {
    setState(() {
      _selectedLibrarySymbol = symbol;
    });
  }

  String? _getPropertyValue(
    List<kicad_symbol_models.Property> properties,
    String propertyName,
  ) {
    for (final p in properties) {
      if (p.name == propertyName) {
        return p.value;
      }
    }
    return null;
  }

  

  void _updateSymbolProperty(SymbolInstance symbol, kicad_symbol_models.Property updatedProperty) {
    if (_loadedSchematic == null) return;

    final symbolIndex = _loadedSchematic!.symbolInstances.indexWhere((s) => s.uuid == symbol.uuid);
    if (symbolIndex != -1) {
      final propertyIndex = _loadedSchematic!.symbolInstances[symbolIndex].properties.indexWhere((p) => p.name == updatedProperty.name);
      if (propertyIndex != -1) {
        setState(() {
          _loadedSchematic!.symbolInstances[symbolIndex].properties[propertyIndex] = updatedProperty;
        });
        _updateConnectivity();
      }
    }
  }

  Future<void> _handleImageDrop(List<String> imagePaths) async {
    print('[MainScreen] Handling image drop with paths: $imagePaths');
    if (currentProject == null) {
      print('[MainScreen] Project is null. Aborting drop.');
      return;
    }

    setState(() {
      print('[MainScreen] Setting processing state to true.');
      _isProcessingImage = true;
    });

    try {
      var project = currentProject!;
      for (final path in imagePaths) {
        print('[MainScreen] Processing path: $path');
        final enhancedPath = await image_processor.enhanceImage(path);
        print('[MainScreen] Enhanced image path: $enhancedPath');
        final newImage = pcbImageViewFromJson({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'path': enhancedPath,
          'layer': 'top',
          'componentPlacements': <String, dynamic>{},
          'modification': imageModificationToJson(
            createDefaultImageModification(),
          ),
        });
        final updatedImages = List<PCBImageView>.from(project.pcbImages)
          ..add(newImage);
        project = project.copyWith(pcbImages: updatedImages);
        print('[MainScreen] Added new image to project state.');
      }

      setState(() {
        currentProject = project;
        _currentView = ViewMode.pcb; // Switch to pcb view to show the new image
        _currentImageIndex = project.pcbImages.length - 1;
        print('[MainScreen] Final project state updated.');
      });
    } catch (e) {
      print('[MainScreen] Error during image drop processing: $e');
    } finally {
      setState(() {
        print('[MainScreen] Setting processing state to false.');
        _isProcessingImage = false;
      });
    }
  }

  // to remove
  void _addComponent(Map<String, dynamic> componentData) {
    if (_loadedSchematic == null || _symbolLoader == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Schematic or symbol library not loaded.")),
          );
        }
      });
      return;
    }

    final String type = componentData['type'];
    final String value = componentData['value'];
    // The 'name' from the dialog is the reference, e.g., "R1"
    final String reference = componentData['name'];

    // final librarySymbol = _symbolLoader!.getSymbolByName(type);
    // Try to resolve the library symbol from selected, loader, or schematic library in a null-safe way.
    kicad_symbol_models.LibrarySymbol? librarySymbol = _selectedLibrarySymbol; // ?? _selectedlibrarySymbol : _symbolLoader?.getSymbolByName(type);
    if (librarySymbol == null && _loadedSchematic?.library?.librarySymbols != null) {
      final libSymbols = _loadedSchematic!.library!.librarySymbols;
      final matches = libSymbols.where((s) => s.name == type);
      if (matches.isNotEmpty) {
        librarySymbol = matches.first;
      }
    }

    if (librarySymbol == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Symbol '$type' not found in library.")),
          );
        }
      });
      return;
    }

    // Check if reference is unique
    if (reference.isNotEmpty && _loadedSchematic!.symbolInstances.any((inst) =>
        inst.properties.any((prop) =>
            prop.name == 'Reference' && prop.value == reference))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Component with reference '$reference' already exists.")),
          );
        }
      });
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
    final newRef = reference.isNotEmpty ? reference : _generateNewRef(prefix);

    final newSymbolInstance = SymbolInstance(
      libId: librarySymbol.name,
      at: const kicad_symbol_models.Position(150, 100), // Default position
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

    final updatedInstances = List<SymbolInstance>.from(_loadedSchematic!.symbolInstances)
      ..add(newSymbolInstance);

    setState(() {
      _loadedSchematic = _loadedSchematic!.copyWith(symbolInstances: updatedInstances);
    });
    _updateConnectivity();
  }

  String _generateNewRef(String prefix) {
    int maxNum = 0;
    for (final inst in _loadedSchematic!.symbolInstances) {
      final refProp = inst.properties.firstWhere(
            (p) => p.name == 'Reference',
        orElse: () => kicad_symbol_models.Property(name: 'Reference', value: '', position: kicad_symbol_models.Position(0, 0), effects: kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1, height: 1), justify: kicad_symbol_models.Justify.left, hide: false)),
      );
      if (refProp.value.startsWith(prefix)) {
        try {
          final num = int.parse(refProp.value.substring(prefix.length));
          if (num > maxNum) {
            maxNum = num;
          }
        } catch (e) {
          // Ignore parsing errors for references like "U?"
        }
      }
    }
    return '$prefix${maxNum + 1}';
  }


  void _addSymbolInstance() {

    if (_loadedSchematic == null || _symbolLoader == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Schematic or symbol library not loaded.")),
          );
        }
      });
      return;
    }

    // final librarySymbol = _symbolLoader!.getSymbolByName(type);
    // Try to resolve the library symbol from selected, loader, or schematic library in a null-safe way.
    kicad_symbol_models.LibrarySymbol? librarySymbol = _selectedLibrarySymbol; // ?? _selectedlibrarySymbol : _symbolLoader?.getSymbolByName(type);
    if (librarySymbol == null && _loadedSchematic?.library?.librarySymbols != null) {
      final libSymbols = _loadedSchematic!.library!.librarySymbols;

      final matches = libSymbols.where((s) => s.name == _selectedSymbolInstance?.libId);
      if (matches.isNotEmpty) {
        librarySymbol = matches.first;
      }
    }

    if (librarySymbol == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Symbol not found. You have to select a symbol from the library list first.")),
          );
        }
      });
      return;
    }

    // Check if reference is unique
    // if (reference.isNotEmpty && _loadedSchematic!.symbolInstances.any((inst) =>
    //     inst.properties.any((prop) =>
    //         prop.name == 'Reference' && prop.value == reference))) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (mounted) {
    //       ScaffoldMessenger.of(context).showSnackBar(
    //         SnackBar(content: Text("Component with reference '$reference' already exists.")),
    //       );
    //     }
    //   });
    //   return;
    // }
    
    kicad_symbol_models.Property? maybeProperty;
    try {
      maybeProperty = librarySymbol.properties.firstWhere(
        (p) => p.name == 'Reference',
      );
    } catch (e) {
      maybeProperty = null;
    }
    final prefix = maybeProperty?.value.replaceAll(RegExp(r'\d'), '') ?? 'X';
    // final newRef = _generateNewRef(prefix);
    // final propertyReference  = librarySymbol.properties.firstWhere((p) => p.name == 'Reference', orElse: () => kicad_symbol_models.Property(name: 'Reference', value: '', position: kicad_symbol_models.Position(0, 0), effects: kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1, height: 1), justify: kicad_symbol_models.Justify.left, hide: false)));
    final propertyValue = librarySymbol.properties.firstWhere((p) => p.name == 'Value', orElse: () => kicad_symbol_models.Property(name: 'Value', value: '', position: kicad_symbol_models.Position(0, 0), effects: kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1, height: 1), justify: kicad_symbol_models.Justify.left, hide: false)));

    // final newSymbolInstance = SymbolInstance(
    //   libId: librarySymbol.name,
    //   at: position,
    //   uuid: Uuid().v4(),
    //   unit: 1,
    //   inBom: true,
    //   onBoard: true,
    //   dnp: false,
    //   properties: [
    //     kicad_symbol_models.Property(name: 'Reference', value: newRef, position: kicad_symbol_models.Position(propertyReference.position.x + position.x, propertyReference.position.y + position.y), effects: const kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1.27, height: 1.27), justify: kicad_symbol_models.Justify.left, hide: false)),
    //     kicad_symbol_models.Property(name: 'Value', value: propertyValue.value, position: kicad_symbol_models.Position(propertyValue.position.x + position.x, propertyValue.position.y + position.y), effects: const kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1.27, height: 1.27), justify: kicad_symbol_models.Justify.left, hide: false)),
    //     kicad_symbol_models.Property(name: 'Footprint', value: "", position: kicad_symbol_models.Position(0, 0), effects: const kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1.27, height: 1.27), justify: kicad_symbol_models.Justify.left, hide: true)),
    //     kicad_symbol_models.Property(name: 'Datasheet', value: "", position: kicad_symbol_models.Position(0, 0), effects: const kicad_symbol_models.TextEffects(font: kicad_symbol_models.Font(width: 1.27, height: 1.27), justify: kicad_symbol_models.Justify.left, hide: true)),
    //   ],
    // );

    // final updatedInstances = List<SymbolInstance>.from(_loadedSchematic!.symbolInstances)
    //   ..add(newSymbolInstance);

    // Use the new API to add the symbol
    setState(() {
      _loadedSchematic = _schematicAPI.addSymbolInstance(
        schematic: _loadedSchematic!,
        symbolLibId: librarySymbol!.name,
        reference: _generateNewRef(prefix),
        value: propertyValue.value,
        position: kicad_symbol_models.Position(150, 100), // Default position
      );
    });
    _updateConnectivity();
  }

  void addWireConnection(
    Position start,
    Position end,
  ) {
    if (_loadedSchematic == null) return;

    final updatedSchematic = _schematicAPI.addWire(
      schematic: _loadedSchematic!,
      points: [start, end],
    );

    setState(() {
      _loadedSchematic = updatedSchematic;
    });
    _updateConnectivity();
  }

  // Example of how to add a junction programmatically
  void addJunctionAtPosition(Position position) {
    if (_loadedSchematic == null) return;

    final updatedSchematic = _schematicAPI.addJunction(
      schematic: _loadedSchematic!,
      position: position,
    );

    setState(() {
      _loadedSchematic = updatedSchematic;
    });
    _updateConnectivity();
  }

  // Example of how to add a label programmatically
  void addNetLabel(String netName, Position position) {
    if (_loadedSchematic == null) return;

    final updatedSchematic = _schematicAPI.addLabel(
      schematic: _loadedSchematic!,
      text: netName,
      position: position,
    );

    setState(() {
      _loadedSchematic = updatedSchematic;
    });
    _updateConnectivity();
  }







  void _addMeasurement(String type, dynamic value) {
    // This function is now only for actual measurements.
    // The component addition logic has been moved to _addComponent.
    // For now, we'll just print a debug message.
    print('Recording measurement: Type=$type, Value=$value');
  }

  void _handleTap(Offset position) {
    // This logic is part of the old workflow and might need to be adapted or removed.
    if (_currentView == ViewMode.pcb &&
        _draggingComponent != null &&
        currentProject != null) {
      // This logic for placing components on a PCB image is complex
      // and needs to be reviewed in the context of the full application.
      // For now, we'll leave it as is.
    }
  }

  void _updateImageModification(ImageModification mod) {
    if (currentProject == null || currentProject!.pcbImages.isEmpty) return;

    final imageToUpdate = currentProject!.pcbImages[_currentImageIndex];
    final updatedImage = pcbImageViewFromJson({
      ...pcbImageViewToJson(imageToUpdate),
      'modification': imageModificationToJson(mod),
    });

    final newImages = List<PCBImageView>.from(currentProject!.pcbImages);
    newImages[_currentImageIndex] = updatedImage;

    setState(() {
      currentProject = currentProject!.copyWith(pcbImages: newImages);
    });
  }

  Future<void> _saveProject() async {
    if (currentProject == null) return;
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'project.pcbrev',
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsString(jsonEncode(projectToJson(currentProject!)));
    }
  }

  Future<void> _openProject() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        // type: FileType.custom,
        // allowedExtensions: ['pcbrev'],
        );

    if (result != null) {
      final file = File(result.files.single.path!);
      if (!file.path.endsWith('.pcbrev')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid file type. Please select a .pcbrev file.'),
              ),
            );
          }
        });
        return;
      }
      final content = await file.readAsString();
      final project = projectFromJson(jsonDecode(content));
      setState(() {
        currentProject = project;
        _currentImageIndex = 0;
        _loadedSchematic = null;
        _currentView = ViewMode.pcb;
      });

      if (project.schematicFilePath != null) {
        await _loadSchematicFile(project.schematicFilePath!);
      }
    }
  }

  Future<void> _exportNetlist() async {
    if (_connectivity == null) {
      print('Cannot export netlist, connectivity not available.');
      // Optionally, show a snackbar to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connectivity data not available. Is a schematic loaded?'),
        ),
      );
      return;
    }
    final netlist = netlist_api.getNetlist(_connectivity!.graph);
    // Further export logic would go here (e.g., save to file)
    print('--- Generated Netlist (JSON) ---');
    print(netlist);
    print('---------------------------------');

    // For demonstration, also show a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generated Netlist'),
        content: Scrollbar(
          child: SingleChildScrollView(
            child: Text(netlist),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveKiCadSchematic() async {
    if (_loadedSchematic == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No schematic loaded to save.'),
            ),
          );
        }
      });
      return;
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select where to save the schematic:',
      fileName: 'schematic.kicad_sch',
      allowedExtensions: ['kicad_sch'],
    );

    if (outputFile != null) {
      try {
        final content = generateKiCadSchematicFileContent(_loadedSchematic!);
        final file = File(outputFile);
        await file.writeAsString(content);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Schematic saved successfully to $outputFile'),
              ),
            );
          }
        });
      } catch (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving schematic: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }
}
