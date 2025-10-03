// project/presentation/app_reducer.dart
import 'package:flutter/material.dart';

import '../../kicad/api/kicad_schematic_api_impl.dart';
import '../../features/connectivity/domain/connectivity_adapter.dart';
import '../api/application_api.dart';
import 'project_operations.dart';
import 'image_operations.dart';
import 'schematic_operations.dart';
import 'symbol_operations.dart';
import '../data/project.dart';
import '../data/app_state.dart';
import '../data/app_actions.dart';
import '../presentation/main_screen.dart';

/// Main reducer that orchestrates all state transitions
Future<AppState> reduceAppAction(
  AppState state,
  AppAction action, {
  required ApplicationAPI api,
  required KiCadSchematicAPIImpl schematicApi,
  required ConnectivityAdapter connectivityAdapter,
  required BuildContext context,
}) async {
  return switch (action) {
    // Initialization
    InitializeAppAction() => await _initialize(state, api, connectivityAdapter),
    
    // Project
    OpenProjectDialogAction() => await _openProjectDialog(state, api, context),
    OpenProjectSuccessAction() => _openProjectSuccess(state, action, connectivityAdapter),
    SaveProjectDialogAction() => await _saveProjectDialog(state, api, context),
    UpdateProjectAction() => state.copyWith(project: action.project),
    
    // Images
    AddImagesAction() => await _addImages(state, action, api, context),
    NavigateImageAction() => _navigateImage(state, action),
    UpdateImageModificationAction() => _updateImageMod(state, action),
    
    // Schematic
    OpenSchematicDialogAction() => await _openSchematicDialog(state, api, connectivityAdapter, context),
    LoadSchematicSuccessAction() => _loadSchematicSuccess(state, action, connectivityAdapter),
    SaveSchematicDialogAction() => await _saveSchematicDialog(state, api, context),
    UpdateSchematicAction() => _updateSchematic(state, action, connectivityAdapter),
    AddSymbolInstanceAction() => _addSymbolInstance(state, schematicApi, connectivityAdapter, context),
    AddComponentAction() => _addComponent(state, action, schematicApi, connectivityAdapter, context),
    UpdateSymbolPropertyAction() => _updateSymbolProperty(state, action, connectivityAdapter),
    
    // Selection
    SelectSymbolInstanceAction() => _selectSymbolInstance(state, action),
    SelectLibrarySymbolAction() => state.copyWith(selectedLibrarySymbol: action.symbol),
    SelectComponentAction() => _selectComponent(state, action, schematicApi),
    SelectNetAction() => state.copyWith(
      selectedNet: action.net,
      clearSelectedSymbol: true,
    ),
    
    // View
    SwitchViewAction() => state.copyWith(currentView: action.view),
    
    // Measurement
    AddMeasurementAction() => state, // TODO: Implement measurement state updates
    
    // Netlist
    ExportNetlistAction() => _exportNetlist(state, api, context),
  };
}

// ============================================================================
// Initialization
// ============================================================================

Future<AppState> _initialize(
  AppState state,
  ApplicationAPI api,
  ConnectivityAdapter connectivityAdapter,
) async {
  final projectResult = createProject('1', 'New Project');
  
  // Load default schematic
  final schematicResult = await loadSchematic(
    api,
    'test/kiProject1/kiProject1.kicad_sch',
  );
  
  // Load default symbol library
  final symbolLoaderResult = await loadDefaultSymbolLibrary(
    'test/kiProject1/example_kicad_symbols.kicad_sym',
  );
  
  var newState = state.copyWith(project: projectResult.project);
  
  if (schematicResult.success && schematicResult.schematic != null) {
    newState = newState.copyWith(
      schematic: schematicResult.schematic,
      project: newState.project?.copyWith(
        schematicFilePath: 'test/kiProject1/kiProject1.kicad_sch',
      ),
    );
  }
  
  if (symbolLoaderResult.success && symbolLoaderResult.loader != null) {
    newState = newState.copyWith(symbolLoader: symbolLoaderResult.loader);
  }
  
  // Update connectivity
  if (newState.schematic != null && newState.symbolLoader != null) {
    final connectivity = connectivityAdapter.updateConnectivity(
      schematic: newState.schematic!,
      symbolLoader: newState.symbolLoader,
    );
    newState = newState.copyWith(connectivity: connectivity);
  }
  
  return newState;
}

// ============================================================================
// Project Operations
// ============================================================================

Future<AppState> _openProjectDialog(
  AppState state,
  ApplicationAPI api,
  BuildContext context,
) async {
  
  final projectResult = await loadProject(api);
  
  if (!projectResult.success) {
    _showError(context, 'Error opening project: ${projectResult.error}');
    return state;
  }
  
  return state.copyWith(
    project: projectResult.project,
    currentImageIndex: 0,
    currentView: ViewMode.pcb,
  );
}

AppState _openProjectSuccess(
  AppState state,
  OpenProjectSuccessAction action,
  ConnectivityAdapter connectivityAdapter,
) {
  var newState = state.copyWith(
    project: action.project,
    schematic: action.schematic,
    currentImageIndex: 0,
    currentView: ViewMode.pcb,
  );
  
  if (newState.schematic != null && newState.symbolLoader != null) {
    final connectivity = connectivityAdapter.updateConnectivity(
      schematic: newState.schematic!,
      symbolLoader: newState.symbolLoader,
    );
    newState = newState.copyWith(connectivity: connectivity);
  }
  
  return newState;
}

Future<AppState> _saveProjectDialog(
  AppState state,
  ApplicationAPI api,
  BuildContext context,
) async {
  
  final result = await saveProject(api, state.project!);
  
  if (result.success) {
    _showSuccess(context, 'Project saved successfully');
  } else {
    _showError(context, 'Error saving project: ${result.error}');
  }
  
  return state;
}

// ============================================================================
// Image Operations
// ============================================================================

Future<AppState> _addImages(
  AppState state,
  AddImagesAction action,
  ApplicationAPI api,
  BuildContext context,
) async {
  if (state.project == null) return state;
  
  final result = await addImageToProject(
    api: api,
    project: state.project!,
    imagePaths: action.paths,
  );
  
  if (!result.success) {
    _showError(context, 'Error processing images: ${result.error}');
    return state.copyWith(isProcessingImage: false);
  }
  
  return state.copyWith(
    project: result.project,
    currentImageIndex: result.newIndex ?? state.currentImageIndex,
    currentView: ViewMode.pcb,
    isProcessingImage: false,
  );
}

AppState _navigateImage(AppState state, NavigateImageAction action) {
  if (state.project == null) return state;
  
  final newIndex = state.currentImageIndex + action.delta;
  if (newIndex < 0 || newIndex >= state.project!.pcbImages.length) {
    return state;
  }
  
  return state.copyWith(currentImageIndex: newIndex);
}

AppState _updateImageMod(AppState state, UpdateImageModificationAction action) {
  if (state.project == null) return state;
  
  final updatedProject = updateImageModification(
    state.project!,
    state.currentImageIndex,
    action.modification,
  );
  
  return state.copyWith(project: updatedProject);
}

// ============================================================================
// Schematic Operations
// ============================================================================

Future<AppState> _openSchematicDialog(
  AppState state,
  ApplicationAPI api,
  ConnectivityAdapter connectivityAdapter,
  BuildContext context,
) async {

  final schematicResult = await loadSchematicFromPicker(api);
  
  if (!schematicResult.success) {
    _showError(context, 'Error loading schematic: ${schematicResult.error}');
    return state;
  }
  
  var newState = state.copyWith(
    schematic: schematicResult.schematic,
    currentView: ViewMode.schematic,
  );
  
  if (newState.project != null) {
    newState = newState.copyWith(
      project: newState.project!.copyWith(schematicFilePath: schematicResult.path),
    );
  }
  
  if (newState.symbolLoader != null) {
    final connectivity = connectivityAdapter.updateConnectivity(
      schematic: newState.schematic!,
      symbolLoader: newState.symbolLoader,
    );
    newState = newState.copyWith(connectivity: connectivity);
  }
  
  return newState;
}

AppState _loadSchematicSuccess(
  AppState state,
  LoadSchematicSuccessAction action,
  ConnectivityAdapter connectivityAdapter,
) {
  var newState = state.copyWith(
    schematic: action.schematic,
    currentView: ViewMode.schematic,
  );
  
  if (action.path != null && newState.project != null) {
    newState = newState.copyWith(
      project: newState.project!.copyWith(schematicFilePath: action.path),
    );
  }
  
  if (newState.symbolLoader != null) {
    final connectivity = connectivityAdapter.updateConnectivity(
      schematic: newState.schematic!,
      symbolLoader: newState.symbolLoader,
    );
    newState = newState.copyWith(connectivity: connectivity);
  }
  
  return newState;
}

Future<AppState> _saveSchematicDialog(
  AppState state,
  ApplicationAPI api,
  BuildContext context,
) async {

  final result = await saveKiCadSchematicFromPicker(api, state.schematic!);

  if (result.success) {
    _showSuccess(context, 'Schematic saved successfully');
  } else {
    _showError(context, 'Error saving schematic: ${result.error}');
  }
  
  return state;
}

AppState _updateSchematic(
  AppState state,
  UpdateSchematicAction action,
  ConnectivityAdapter connectivityAdapter,
) {
  var newState = state.copyWith(schematic: action.schematic);
  
  if (newState.symbolLoader != null) {
    final connectivity = connectivityAdapter.updateConnectivity(
      schematic: newState.schematic!,
      symbolLoader: newState.symbolLoader,
    );
    newState = newState.copyWith(connectivity: connectivity);
  }
  
  return newState;
}

AppState _addSymbolInstance(
  AppState state,
  KiCadSchematicAPIImpl schematicApi,
  ConnectivityAdapter connectivityAdapter,
  BuildContext context,
) {
  if (state.schematic == null || state.symbolLoader == null) {
    _showError(context, 'Schematic or symbol library not loaded.');
    return state;
  }
  
  final schematic = addSymbolInstance(
    schematicApi,
    state.selectedLibrarySymbol,
    state.selectedSymbol,
    state.schematic!,
    state.symbolLoader!,
  );
  
  // if (!result) {
  //   _showError(context, result?.error ?? 'Failed to add symbol');
  //   return state;
  // }
  
  var newState = state.copyWith(schematic: schematic);
  
  final connectivity = connectivityAdapter.updateConnectivity(
    schematic: newState.schematic!,
    symbolLoader: newState.symbolLoader,
  );
  
  return newState.copyWith(connectivity: connectivity);
}

AppState _addComponent(
  AppState state,
  AddComponentAction action,
  KiCadSchematicAPIImpl schematicApi,
  ConnectivityAdapter connectivityAdapter,
  BuildContext context,
) {
  if (state.schematic == null || state.symbolLoader == null) {
    _showError(context, 'Schematic or symbol library not loaded.');
    return state;
  }
  
  final result = addComponent(
    schematicApi,
    action.componentData,
    state.selectedLibrarySymbol,
    state.schematic!,
    state.symbolLoader!,
  );
  
  // if (!result.success) {
  //   _showError(context, result.error ?? 'Failed to add component');
  //   return state;
  // }
  
  var newState = state.copyWith(schematic: result);
  
  final connectivity = connectivityAdapter.updateConnectivity(
    schematic: newState.schematic!,
    symbolLoader: newState.symbolLoader,
  );
  
  return newState.copyWith(connectivity: connectivity);
}

AppState _updateSymbolProperty(
  AppState state,
  UpdateSymbolPropertyAction action,
  ConnectivityAdapter connectivityAdapter,
) {
  if (state.schematic == null) return state;
  
  final result = updateSymbolProperty(
    action.symbol,
    action.property,
    state.schematic!,
  );
  
  // if (!result.success) return state;
  
  var newState = state.copyWith(schematic: result);
  
  if (newState.symbolLoader != null) {
    final connectivity = connectivityAdapter.updateConnectivity(
      schematic: newState.schematic!,
      symbolLoader: newState.symbolLoader,
    );
    newState = newState.copyWith(connectivity: connectivity);
  }
  
  return newState;
}

// ============================================================================
// Selection Operations
// ============================================================================

AppState _selectSymbolInstance(
  AppState state,
  SelectSymbolInstanceAction action,
) {
  return state.copyWith(
    selectedSymbol: action.symbol,
    clearSelectedNet: true,
  );
}

AppState _selectComponent(
  AppState state,
  SelectComponentAction action,
  KiCadSchematicAPIImpl schematicApi,
) {
  if (state.schematic == null) return state;
  
  final result = findSymbolByReference(
    schematic: state.schematic!,
    schematicApi: schematicApi,
    reference: action.component.id,  // TODO: change to use component.partNumber
  );
  
  if (!result.success || result.symbol == null) return state;
  
  return state.copyWith(
    selectedSymbol: result.symbol,
    selectedLibrarySymbol: result.librarySymbol,
    centerOnPosition: result.position,
    currentView: ViewMode.schematic,
  );
}

// ============================================================================
// Netlist Operations
// ============================================================================

AppState _exportNetlist(
  AppState state,
  ApplicationAPI api,
  BuildContext context,
) {
  if (state.connectivity == null) {
    _showError(context, 'Connectivity data not available. Is a schematic loaded?');
    return state;
  }
  
  final netlist = api.exportNetlist(state.connectivity!);
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Generated Netlist'),
      content: Scrollbar(
        child: SingleChildScrollView(
          child: Text(netlist),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  
  return state;
}

// ============================================================================
// UI Helpers
// ============================================================================

void _showError(BuildContext context, String message) {
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

void _showSuccess(BuildContext context, String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  });
}