import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../pcb_viewer/presentation/pcb_viewer_panel.dart';
import '../../global_list/presentation/widgets/global_list_panel.dart';
import '../../measurement/presentation/properties_panel.dart';

import '../../kicad/presentation/schematic_view.dart';
import '../../kicad/api/kicad_schematic_api_impl.dart';
import '../../kicad/data/kicad_symbol_models.dart';

import '../../features/connectivity/domain/connectivity_adapter.dart';

import '../../features/ai_integration/data/mcp_server.dart';
import '../../features/ai_integration/data/schematic_edit_mcp.dart';
import '../../features/ai_integration/domain/schematic_edit_tools.dart';
import '../../features/ai_integration/data/project_mcp.dart';
import '../../features/ai_integration/domain/project_mcp_tools.dart';

import '../api/application_api.dart';

import '../data/app_state.dart';
import '../data/app_actions.dart';
import '../domain/app_reducer.dart';

enum ViewMode { pcb, schematic }

class PCBAnalyzerApp extends StatefulWidget {
  const PCBAnalyzerApp({Key? key}) : super(key: key);

  @override
  _PCBAnalyzerAppState createState() => _PCBAnalyzerAppState();
}

class _PCBAnalyzerAppState extends State<PCBAnalyzerApp> {
  // Dependencies
  late final ApplicationAPI _api;
  late final KiCadSchematicAPIImpl _schematicApi;
  late final ConnectivityAdapter _connectivityAdapter;
  MCPServer? _mcpServer;

  // State
  AppState _state = AppState();
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _api = ApplicationAPI();
    _schematicApi = KiCadSchematicAPIImpl();
    _connectivityAdapter = ConnectivityAdapter();
    
    _initializeServer();
    _initializeApp();
  }

  void _initializeServer() {
    _mcpServer = MCPServer(
      getSchematic: () => _state.schematic,
      updateSchematic: (newSchematic) => _dispatch(UpdateSchematicAction(newSchematic)),
      getSymbolLibraries: () {
        final libs = <KiCadLibrary>[];
        if (_state.schematic?.library != null) {
          libs.add(_state.schematic!.library!);
        }
        return libs;
      },
      getConnectivity: () => _state.connectivity,
    );

    _mcpServer!.registerToolHandlers(_mcpServer!.schematicEditToolHandlers);
    _mcpServer!.registerToolDefinitions(schematicEditTools);

    final projectHandlers = _mcpServer!.projectToolHandlers(
      onProjectOpened: (openedProject) => _dispatch(
        OpenProjectSuccessAction(openedProject.project, openedProject.schematic)
      ),
      onSchematicLoaded: (schematic) => _dispatch(LoadSchematicSuccessAction(schematic)),
      getProject: () => _state.project,
      updateProject: (newProject) => _dispatch(UpdateProjectAction(newProject)),
      onComponentSelected: (component) => _dispatch(SelectComponentAction(component)), 
    );

    _mcpServer!.registerToolHandlers(projectHandlers);
    _mcpServer!.registerToolDefinitions(projectMcpTools);
    _mcpServer!.start();
  }

  Future<void> _initializeApp() async {
    await _dispatch(InitializeAppAction());
  }

  Future<void> _dispatch(AppAction action) async {
    final newState = await reduceAppAction(
      _state,
      action,
      api: _api,
      schematicApi: _schematicApi,
      connectivityAdapter: _connectivityAdapter,
      context: context,
    );
    
    if (mounted) {
      setState(() => _state = newState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) => _dispatch(
        AddImagesAction(detail.files.map((f) => f.path).toList())
      ),
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            Row(
              children: [
                Expanded(flex: 1, child: _buildLeftPanel()),
                Expanded(flex: 5, child: _buildMainPanel()),
                Expanded(flex: 1, child: _buildRightPanel()),
              ],
            ),
            if (_dragging) _buildDragOverlay(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_state.project?.name ?? 'PCB Analyzer'),
      actions: [
        _buildViewToggle(),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.description),
          onPressed: () => _dispatch(OpenSchematicDialogAction()),
          tooltip: 'Load KiCad Schematic',
        ),
        IconButton(
          icon: const Icon(Icons.folder_open),
          onPressed: () => _dispatch(OpenProjectDialogAction()),
        ),
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: () => _dispatch(SaveProjectDialogAction()),
        ),
        IconButton(
          icon: const Icon(Icons.save_as),
          onPressed: () => _dispatch(SaveSchematicDialogAction()),
          tooltip: 'Save KiCad Schematic',
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => _dispatch(ExportNetlistAction()),
        ),
      ],
    );
  }

  Widget _buildViewToggle() {
    return ToggleButtons(
      isSelected: [
        _state.currentView == ViewMode.pcb,
        _state.currentView == ViewMode.schematic,
      ],
      onPressed: (index) => _dispatch(
        SwitchViewAction(index == 0 ? ViewMode.pcb : ViewMode.schematic)
      ),
      children: const [
        Icon(Icons.image),
        Icon(Icons.schema),
      ],
    );
  }

  Widget _buildLeftPanel() {
    return GlobalListPanel(
      // components: _state.project?.logicalComponents.values.toList() ?? [],
      nets: _state.connectivity?.nets ?? [],
      onComponentSelected: (component) => _dispatch(SelectComponentAction(component)),
      onNetSelected: (net) => _dispatch(SelectNetAction(net)),
      schematic: _state.schematic,
      onLibrarySymbolSelected: (symbol) => _dispatch(SelectLibrarySymbolAction(symbol)),
    );
  }

  Widget _buildMainPanel() {
    return switch (_state.currentView) {
      ViewMode.schematic => _buildSchematicView(),
      ViewMode.pcb => _buildPCBView(),
    };
  }

  Widget _buildSchematicView() {
    if (_state.schematic == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No schematic loaded.'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _dispatch(OpenSchematicDialogAction()),
              child: const Text('Load KiCad Schematic'),
            ),
          ],
        ),
      );
    }

    return SchematicView(
      schematic: _state.schematic!,
      centerOn: _state.centerOnPosition,
      selectedSymbolInstanceId: _state.selectedSymbol?.uuid,
      onSymbolInstanceSelected: (symbol) => _dispatch(SelectSymbolInstanceAction(symbol)),
    );
  }

  Widget _buildPCBView() {
    return PCBViewerPanel(
      project: _state.project,
      isProcessingImage: _state.isProcessingImage,
      draggingComponent: null,
      currentIndex: _state.currentImageIndex,
      onImageDrop: (paths) => _dispatch(AddImagesAction(paths)),
      onNext: () => _dispatch(NavigateImageAction(1)),
      onPrevious: () => _dispatch(NavigateImageAction(-1)),
      onImageModification: (mod) => _dispatch(UpdateImageModificationAction(mod)),
      onTap: (_) {}, // Placeholder
      symbolLoader: _state.symbolLoader,
    );
  }

  Widget _buildRightPanel() {
    return PropertiesPanel(
      selectedSymbolInstance: _state.selectedSymbol,
      selectedNet: _state.selectedNet,
      measurementState: _state.measurementState,
      onMeasurementAdded: (type, value) => _dispatch(AddMeasurementAction(type, value)),
      onComponentAdded: (data) => _dispatch(AddComponentAction(data)),
      onAddSymbolInstance: () => _dispatch(AddSymbolInstanceAction()),
      onPropertyUpdated: (symbol, property) => 
        _dispatch(UpdateSymbolPropertyAction(symbol, property)),
    );
  }

  Widget _buildDragOverlay() {
    return Container(
      color: Colors.blue.withOpacity(0.2),
      child: const Center(
        child: Icon(
          Icons.add_photo_alternate,
          color: Colors.white,
          size: 100,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mcpServer?.stop();
    super.dispose();
  }
}