// project/presentation/app_actions.dart
import '../../kicad/data/kicad_schematic_models.dart';
import '../../kicad/data/kicad_symbol_models.dart' as kicad_symbol;
import '../../features/connectivity/models/core.dart' as connectivity_core;
import '../../pcb_viewer/data/image_modification.dart';
import 'logical_models.dart';
import 'project.dart';
import '../presentation/main_screen.dart' show ViewMode;

sealed class AppAction {}

// ============================================================================
// Initialization
// ============================================================================

class InitializeAppAction extends AppAction {}

// ============================================================================
// Project Actions
// ============================================================================

class OpenProjectDialogAction extends AppAction {}

class OpenProjectSuccessAction extends AppAction {
  final Project project;
  final KiCadSchematic? schematic;
  OpenProjectSuccessAction(this.project, this.schematic);
}

class SaveProjectDialogAction extends AppAction {}

class UpdateProjectAction extends AppAction {
  final Project project;
  UpdateProjectAction(this.project);
}

// ============================================================================
// Image Actions
// ============================================================================

class AddImagesAction extends AppAction {
  final List<String> paths;
  AddImagesAction(this.paths);
}

class NavigateImageAction extends AppAction {
  final int delta;
  NavigateImageAction(this.delta);
}

class UpdateImageModificationAction extends AppAction {
  final ImageModification modification;
  UpdateImageModificationAction(this.modification);
}

// ============================================================================
// Schematic Actions
// ============================================================================

class OpenSchematicDialogAction extends AppAction {}

class LoadSchematicSuccessAction extends AppAction {
  final KiCadSchematic schematic;
  final String? path;
  LoadSchematicSuccessAction(this.schematic, {this.path});
}

class SaveSchematicDialogAction extends AppAction {}

class UpdateSchematicAction extends AppAction {
  final KiCadSchematic schematic;
  UpdateSchematicAction(this.schematic);
}

class AddSymbolInstanceAction extends AppAction {}

class AddComponentAction extends AppAction {
  final Map<String, dynamic> componentData;
  AddComponentAction(this.componentData);
}

class UpdateSymbolPropertyAction extends AppAction {
  final SymbolInstance symbol;
  final kicad_symbol.Property property;
  UpdateSymbolPropertyAction(this.symbol, this.property);
}

// ============================================================================
// Selection Actions
// ============================================================================

class SelectSymbolInstanceAction extends AppAction {
  final SymbolInstance symbol;
  SelectSymbolInstanceAction(this.symbol);
}

class SelectLibrarySymbolAction extends AppAction {
  final kicad_symbol.LibrarySymbol symbol;
  SelectLibrarySymbolAction(this.symbol);
}

class SelectComponentAction extends AppAction {
  final LogicalComponent component;
  SelectComponentAction(this.component);
}

class SelectNetAction extends AppAction {
  final connectivity_core.Net net;
  SelectNetAction(this.net);
}

// ============================================================================
// View Actions
// ============================================================================

class SwitchViewAction extends AppAction {
  final ViewMode view;
  SwitchViewAction(this.view);
}

// ============================================================================
// Measurement Actions
// ============================================================================

class AddMeasurementAction extends AppAction {
  final String type;
  final dynamic value;
  AddMeasurementAction(this.type, this.value);
}

// ============================================================================
// Netlist Actions
// ============================================================================

class ExportNetlistAction extends AppAction {}
