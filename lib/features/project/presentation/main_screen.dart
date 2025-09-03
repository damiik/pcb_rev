import 'dart:convert';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../features/measurement/data/measurement_service.dart'
    as measurement_service;
import '../../../features/pcb_viewer/data/image_modification.dart';
import '../../../features/pcb_viewer/presentation/pcb_viewer_panel.dart';
import '../../../features/schematic/data/logical_models.dart';
import '../../../features/global_list/presentation/widgets/global_list_panel.dart';
import '../../measurement/presentation/properties_panel.dart';
import '../data/project.dart';
import 'package:pcb_rev/features/pcb_viewer/data/image_processor.dart'
    as image_processor;
import '../../symbol_library/data/kicad_schematic_models.dart';
import '../../symbol_library/data/kicad_schematic_loader.dart';
import '../../symbol_library/data/kicad_symbol_loader.dart';
import 'package:pcb_rev/features/symbol_library/data/kicad_symbol_models.dart'
    as kicad_symbol_models;
import '../../symbol_library/presentation/schematic_view.dart';
import '../../symbol_library/domain/kicad_schematic_writer.dart';


enum ViewMode { pcb, schematic }

class PCBAnalyzerApp extends StatefulWidget {
  @override
  _PCBAnalyzerAppState createState() => _PCBAnalyzerAppState();
}

class _PCBAnalyzerAppState extends State<PCBAnalyzerApp> {
  ViewMode _currentView = ViewMode.pcb;
  Project? currentProject;
  int _currentImageIndex = 0;
  LogicalComponent? _draggingComponent;
  bool _isProcessingImage = false;
  measurement_service.MeasurementState measurementState =
      measurement_service.createInitialMeasurementState();
  bool _dragging = false;
  KiCadSchematic? _loadedSchematic;
  KiCadSymbolLoader? _symbolLoader;
  kicad_symbol_models.Position? _centerOnPosition;
  String? _selectedSymbolId;
  SymbolInstance? _selectedSymbol;

  @override
  void initState() {
    super.initState();
    print('Initializing PCB Analyzer App...');
    _initializeProject();
    _loadDefaultSymbolLibrary();
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
      final loader = KiCadSymbolLoader(libraryPath);
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCB Reverse Engineering',
      theme: ThemeData.dark(),
      home: DropTarget(
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
                      nets: currentProject?.logicalNets.values.toList() ?? [],
                      onComponentSelected: _selectComponent,
                      onNetSelected: _selectNet,
                      schematic: _loadedSchematic,
                    ),
                  ),
                  Expanded(flex: 5, child: _buildMainPanel()),
                  Expanded(
                    flex: 1,
                    child: PropertiesPanel(
                      selectedSymbol: _selectedSymbol,
                      measurementState: measurementState,
                      onMeasurementAdded: _addMeasurement,
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
            selectedSymbolId: _selectedSymbolId,
            onSymbolSelected: (symbol) {
              setState(() {
                _selectedSymbol = symbol;
                _selectedSymbolId = symbol.uuid;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid file type. Please select a .kicad_sch file.',
            ),
          ),
        );
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

    SymbolInstance? foundSymbol;
    for (final symbol in _loadedSchematic!.symbols) {
      final reference = _getPropertyValue(symbol.properties, 'Reference');
      if (reference == component.id) {
        foundSymbol = symbol;
        break;
      }
    }

    if (foundSymbol != null) {
      final symbol = foundSymbol;
      setState(() {
        _selectedSymbol = symbol;
        _centerOnPosition = symbol.at;
        _selectedSymbolId = symbol.uuid;
        _currentView = ViewMode.schematic;
      });
    }
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

  void _selectNet(LogicalNet net) {
    setState(() {
      // Logic to handle net selection in the UI
    });
  }

  void _updateSymbolProperty(SymbolInstance symbol, kicad_symbol_models.Property updatedProperty) {
    if (_loadedSchematic == null) return;

    final symbolIndex = _loadedSchematic!.symbols.indexWhere((s) => s.uuid == symbol.uuid);
    if (symbolIndex != -1) {
      final propertyIndex = _loadedSchematic!.symbols[symbolIndex].properties.indexWhere((p) => p.name == updatedProperty.name);
      if (propertyIndex != -1) {
        setState(() {
          _loadedSchematic!.symbols[symbolIndex].properties[propertyIndex] = updatedProperty;
        });
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

  void _addMeasurement(String type, dynamic value) {
    if (value is Map<String, dynamic>) {
      final newComponent = logicalComponentFromJson({
        'id': value['name'],
        'type': value['type'],
        'value': value['value'],
        'partNumber': '',
        'pins': <String, dynamic>{},
      });
      setState(() {
        _draggingComponent = newComponent;
      });
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid file type. Please select a .pcbrev file.'),
          ),
        );
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
    if (currentProject == null) return;
    final netlist = generateNetlistFromProject(currentProject!);
    // Further export logic would go here
    print(netlist);
  }

  Future<void> _saveKiCadSchematic() async {
    if (_loadedSchematic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No schematic loaded to save.'),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Schematic saved successfully to $outputFile'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving schematic: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
