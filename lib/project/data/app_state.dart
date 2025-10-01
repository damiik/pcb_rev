// project/presentation/app_state.dart
import '../../kicad/data/kicad_schematic_models.dart';
import '../../kicad/data/kicad_symbol_models.dart' as kicad_symbol;
import '../../kicad/data/kicad_symbol_loader.dart';
import '../../features/connectivity/models/connectivity.dart';
import '../../features/connectivity/models/core.dart' as connectivity_core;
import '../../measurement/data/measurement_service.dart' as measurement_service;
import 'project.dart';
import 'logical_models.dart';
import '../presentation/main_screen.dart';

class AppState {
  // Project state
  final Project? project;
  final KiCadSchematic? schematic;
  final KiCadLibrarySymbolLoader? symbolLoader;
  final Connectivity? connectivity;
  
  // UI state
  final int currentImageIndex;
  final ViewMode currentView;
  final bool isProcessingImage;
  
  // Selection state
  final SymbolInstance? selectedSymbol;
  final kicad_symbol.LibrarySymbol? selectedLibrarySymbol;
  final connectivity_core.Net? selectedNet;
  final LogicalComponent? selectedComponent;
  final kicad_symbol.Position? centerOnPosition;
  
  // Measurement state
  final measurement_service.MeasurementState measurementState;

  AppState({
    this.project,
    this.schematic,
    this.symbolLoader,
    this.connectivity,
    this.currentImageIndex = 0,
    this.currentView = ViewMode.pcb,
    this.isProcessingImage = false,
    this.selectedSymbol,
    this.selectedLibrarySymbol,
    this.selectedNet,
    this.selectedComponent,
    this.centerOnPosition,
    measurement_service.MeasurementState? measurementState,
  }): measurementState = measurementState ?? measurement_service.createInitialMeasurementState();

  AppState copyWith({
    Project? project,
    KiCadSchematic? schematic,
    KiCadLibrarySymbolLoader? symbolLoader,
    Connectivity? connectivity,
    int? currentImageIndex,
    ViewMode? currentView,
    bool? isProcessingImage,
    SymbolInstance? selectedSymbol,
    kicad_symbol.LibrarySymbol? selectedLibrarySymbol,
    connectivity_core.Net? selectedNet,
    LogicalComponent? selectedComponent,
    kicad_symbol.Position? centerOnPosition,
    measurement_service.MeasurementState? measurementState,
    bool clearSelectedSymbol = false,
    bool clearSelectedNet = false,
    bool clearCenterOn = false,
  }) {
    return AppState(
      project: project ?? this.project,
      schematic: schematic ?? this.schematic,
      symbolLoader: symbolLoader ?? this.symbolLoader,
      connectivity: connectivity ?? this.connectivity,
      currentImageIndex: currentImageIndex ?? this.currentImageIndex,
      currentView: currentView ?? this.currentView,
      isProcessingImage: isProcessingImage ?? this.isProcessingImage,
      selectedSymbol: clearSelectedSymbol ? null : (selectedSymbol ?? this.selectedSymbol),
      selectedLibrarySymbol: selectedLibrarySymbol ?? this.selectedLibrarySymbol,
      selectedNet: clearSelectedNet ? null : (selectedNet ?? this.selectedNet),
      selectedComponent: selectedComponent ?? this.selectedComponent,
      centerOnPosition: clearCenterOn ? null : (centerOnPosition ?? this.centerOnPosition),
      measurementState: measurementState ?? this.measurementState,
    );
  }
}