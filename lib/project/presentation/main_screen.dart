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
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart';
import '../../kicad/data/kicad_schematic_models.dart';
import '../../kicad/data/kicad_symbol_loader.dart';
import '../../kicad/api/kicad_schematic_api_impl.dart';
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart'
    as kicad_symbol_models;
import '../../kicad/presentation/schematic_view.dart';
import '../../features/ai_integration/data/mcp_server.dart';
import '../../features/ai_integration/data/schematic_edit_mcp.dart';
import '../../features/ai_integration/domain/schematic_edit_tools.dart';
import '../../features/ai_integration/data/project_mcp.dart';
import '../../features/ai_integration/domain/project_mcp_tools.dart';

import 'package:pcb_rev/features/connectivity/models/core.dart' as connectivity_core;
import '../../features/connectivity/domain/connectivity_adapter.dart';
import '../../features/connectivity/models/connectivity.dart';
import '../api/application_api.dart';
import 'project_manager.dart';
import 'schematic_manager.dart';
import 'image_manager.dart';
import 'connectivity_manager.dart';
import 'symbol_manager.dart';


enum ViewMode { pcb, schematic }

class PCBAnalyzerApp extends StatefulWidget {
  const PCBAnalyzerApp({Key? key}) : super(key: key);

  @override
  _PCBAnalyzerAppState createState() => _PCBAnalyzerAppState();
}

class _PCBAnalyzerAppState extends State<PCBAnalyzerApp> {

  final _applicationAPI = ApplicationAPI();
  final _schematicApi = KiCadSchematicAPIImpl();
  MCPServer? _mcpServer;

  // Manager instances
  late final ProjectManager _projectManager;
  late final SchematicManager _schematicManager;
  late final ImageManager _imageManager;
  late final ConnectivityManager _connectivityManager;
  late final SymbolManager _symbolManager;
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

    // Initialize managers
    _projectManager = ProjectManager(_applicationAPI);
    _schematicManager = SchematicManager(_applicationAPI, _schematicApi);
    _imageManager = ImageManager(_applicationAPI);
    _connectivityManager = ConnectivityManager(ConnectivityAdapter());
    _symbolManager = SymbolManager(_schematicApi);

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

    // Register schematic editing tools
    _mcpServer!.registerToolHandlers(_mcpServer!.schematicEditToolHandlers);
    _mcpServer!.registerToolDefinitions(schematicEditTools);

    // Register project management tools callbacks
    final projectHandlers = _mcpServer!.projectToolHandlers(
      onProjectOpened: _applyOpenedProject, // Use the new centralized method
      onSchematicLoaded: (schematic) => _applyLoadedSchematic(schematic, switchToView: true),
      getProject: () => currentProject,
      updateProject: (newProject) {
        setState(() {
          currentProject = newProject;
        });
      }
    );

    // Register project management tools
    _mcpServer!.registerToolHandlers(projectHandlers);
    _mcpServer!.registerToolDefinitions(projectMcpTools);

    _mcpServer!.start();
  }

  /// Centralized method to apply a newly opened project to the application state.
  void _applyOpenedProject(OpenedProject openedProject) {
    setState(() {
      currentProject = openedProject.project;
      _loadedSchematic = openedProject.schematic;
      _currentImageIndex = 0;
      _currentView = ViewMode.pcb;
    });
    _updateConnectivity();
  }

  /// Centralized method to apply a newly loaded schematic to the application state.
  void _applyLoadedSchematic(KiCadSchematic schematic, {String? path, bool switchToView = false}) {
    setState(() {
      _loadedSchematic = schematic;
      if (switchToView) {
        _currentView = ViewMode.schematic;
      }
      if (path != null && currentProject != null) {
        currentProject = currentProject!.copyWith(schematicFilePath: path);
      }
    });
    _updateConnectivity();
  }

  void _initializeProject() {
    setState(() {
      currentProject = _projectManager.createInitialProject();
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
      try {
        final schematic = await _applicationAPI.loadSchematic(defaultSchematicPath);
        _applyLoadedSchematic(schematic, path: defaultSchematicPath, switchToView: false);
      } catch (e) {
        print('Error loading default schematic: $e');
      }
    }
  }

  void _updateConnectivity() {
    setState(() {
      _connectivity = _connectivityManager.updateConnectivity(
        schematic: _loadedSchematic,
        symbolLoader: _symbolLoader,
      );
    });
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
    await _schematicManager.loadSchematic(
      context,
      (schematic, path) {
        _applyLoadedSchematic(schematic, path: path, switchToView: true);
      },
      () {
        // Error handling is done within the manager
      },
    );
  }

  void _navigateImages(int delta) {
    _imageManager.navigateImages(
      delta,
      _currentImageIndex,
      currentProject,
      (newIndex) {
        setState(() => _currentImageIndex = newIndex);
      },
    );
  }

  void _selectComponent(LogicalComponent component) {
    _symbolManager.selectComponent(
      component,
      _loadedSchematic,
      (foundSymbolInstance, librarySymbol, position, uuid) {
        setState(() {
          _selectedSymbolInstance = foundSymbolInstance;
          _selectedLibrarySymbol = librarySymbol;
          _centerOnPosition = position;
          _selectedSymbolInstanceId = uuid;
          _currentView = ViewMode.schematic;
        });
      },
    );
  }

  void _selectLibrarySymbol(kicad_symbol_models.LibrarySymbol symbol) {
    _symbolManager.selectLibrarySymbol(
      symbol,
      (selectedSymbol) {
        setState(() {
          _selectedLibrarySymbol = selectedSymbol;
        });
      },
    );
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
    await _imageManager.handleImageDrop(
      imagePaths,
      currentProject,
      context,
      (project, newIndex) {
        setState(() {
          currentProject = project;
          _currentView = ViewMode.pcb;
          _currentImageIndex = newIndex;
        });
      },
      () {
        // Error handling is done within the manager
      },
    );
  }

  void _addComponent(Map<String, dynamic> componentData) {
    _schematicManager.addComponent(
      componentData,
      _selectedLibrarySymbol,
      _loadedSchematic,
      _symbolLoader,
      context,
      (updatedSchematic) {
        setState(() {
          _loadedSchematic = updatedSchematic;
        });
        _updateConnectivity();
      },
    );
  }


  void _addSymbolInstance() {
    _schematicManager.addSymbolInstance(
      _selectedLibrarySymbol,
      _selectedSymbolInstance,
      _loadedSchematic,
      _symbolLoader,
      context,
      (updatedSchematic) {
        setState(() {
          _loadedSchematic = updatedSchematic;
        });
        _updateConnectivity();
      },
    );
  }

  void addWireConnection(
    Position start,
    Position end,
  ) {
    if (_loadedSchematic == null) return;

    final updatedSchematic = _schematicApi.addWire(
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

    final updatedSchematic = _schematicApi.addJunction(
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

    final updatedSchematic = _schematicApi.addLabel(
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
    _imageManager.updateImageModification(
      mod,
      _currentImageIndex,
      currentProject,
      (updatedProject) {
        setState(() {
          currentProject = updatedProject;
        });
      },
    );
  }

  Future<void> _saveProject() async {
    await _projectManager.saveProject(
      currentProject,
      context,
      () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project saved successfully')),
          );
        }
      },
      () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error saving project'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Future<void> _openProject() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        // type: FileType.custom,
        // allowedExtensions: ['pcbrev'],
        );

    if (result != null) {
      final path = result.files.single.path!;
      if (!path.endsWith('.pcbrev')) {
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

      try {
        final openedProject = await _applicationAPI.openProject(path);
        _applyOpenedProject(openedProject); // Use the new centralized method
      } catch (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error opening project: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _exportNetlist() async {
    if (_connectivity == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connectivity data not available. Is a schematic loaded?'),
          ),
        );
      }
      return;
    }

    try {
      final netlist = _applicationAPI.exportNetlist(_connectivity!);
      print('--- Generated Netlist (JSON) ---');
      print(netlist);
      print('---------------------------------');

      // For demonstration, also show a dialog
      if (mounted) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting netlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveKiCadSchematic() async {
    await _schematicManager.saveKiCadSchematic(
      _loadedSchematic,
      context,
      () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schematic saved successfully')),
          );
        }
      },
      () {
        // Error handling is done within the manager
      },
    );
  }
}
