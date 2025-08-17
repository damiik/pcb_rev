import 'dart:convert';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../features/measurement/data/measurement_service.dart'
    as measurement_service;
import '../../../features/pcb_viewer/data/image_modification.dart';
import '../../../features/pcb_viewer/presentation/pcb_viewer_panel.dart';
import '../../../features/schematic/data/logical_models.dart';
import '../../../features/schematic/data/visual_models.dart' as visual_models;
import '../../../features/global_list/presentation/widgets/global_list_panel.dart';
import '../../measurement/presentation/properties_panel.dart';
import '../data/project.dart';
import 'package:pcb_rev/features/pcb_viewer/data/image_processor.dart'
    as image_processor;
import '../../symbol_library/data/kicad_symbol_models.dart';
import '../../symbol_library/data/kicad_schematic_models.dart';
import '../../symbol_library/data/kicad_schematic_loader.dart';
import '../../symbol_library/presentation/schematic_view.dart';

class PCBAnalyzerApp extends StatefulWidget {
  @override
  _PCBAnalyzerAppState createState() => _PCBAnalyzerAppState();
}

class _PCBAnalyzerAppState extends State<PCBAnalyzerApp> {
  Project? currentProject;
  int _currentImageIndex = 0;
  LogicalComponent? _draggingComponent;
  bool _isProcessingImage = false;
  measurement_service.MeasurementState measurementState = measurement_service
      .createInitialMeasurementState();
  bool _dragging = false;
  KiCadSchematic? _loadedSchematic;

  @override
  void initState() {
    super.initState();
    _initializeProject();
  }

  void _initializeProject() {
    setState(() {
      currentProject = projectFromJson({
        'id': '1',
        'name': 'My Project',
        'lastUpdated': DateTime.now().toIso8601String(),
        'logicalComponents': <String, dynamic>{},
        'logicalNets': <String, dynamic>{},
        'schematic': {
          'symbols': <String, dynamic>{},
          'wires': <String, dynamic>{},
        },
        'pcbImages': <dynamic>[],
      });
    });
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
              IconButton(icon: Icon(Icons.share), onPressed: _exportNetlist),
            ],
          ),
          body: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: GlobalListPanel(
                      components:
                          currentProject?.logicalComponents.values.toList() ??
                          [],
                      nets: currentProject?.logicalNets.values.toList() ?? [],
                      onComponentSelected: _selectComponent,
                      onNetSelected: _selectNet,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: PCBViewerPanel(
                      project: currentProject,
                      isProcessingImage: _isProcessingImage,
                      draggingComponent: _draggingComponent,
                      currentIndex: _currentImageIndex,
                      onImageDrop: _handleImageDrop,
                      onNext: () => _navigateImages(1),
                      onPrevious: () => _navigateImages(-1),
                      onImageModification: _updateImageModification,
                      onTap: _handleTap,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: PropertiesPanel(
                      measurementState: measurementState,
                      onMeasurementAdded: _addMeasurement,
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

  Future<void> _loadSchematic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['kicad_sch'],
    );

    if (result != null) {
      final path = result.files.single.path!;
      final loader = KiCadSchematicLoader(path);
      try {
        final schematic = await loader.load();
        setState(() {
          _loadedSchematic = schematic;
          // You might want to integrate the loaded schematic into your project state here
        });
      } catch (e) {
        // Handle parsing errors, e.g., show a dialog
        print('Error loading schematic: $e');
      }
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
    setState(() {
      // Logic to handle component selection in the UI
    });
  }

  void _selectNet(LogicalNet net) {
    setState(() {
      // Logic to handle net selection in the UI
    });
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
    if (_draggingComponent != null && currentProject != null) {
      final logicalComponent = _draggingComponent!;
      final newSymbol = visual_models.symbolFromJson({
        'id': 'sym_${DateTime.now().millisecondsSinceEpoch}',
        'logicalComponentId': logicalComponent.id,
        'position': visual_models.positionToJson((
          x: position.dx,
          y: position.dy,
        )),
        'rotation': 0.0,
      });

      final newSymbols = Map<String, visual_models.Symbol>.from(
        currentProject!.schematic.symbols,
      );
      newSymbols[newSymbol.id] = newSymbol;

      final newLogicalComponents = Map<String, LogicalComponent>.from(
        currentProject!.logicalComponents,
      );
      newLogicalComponents[logicalComponent.id] = logicalComponent;

      final newSchematic = (
        symbols: newSymbols,
        wires: currentProject!.schematic.wires,
      );

      setState(() {
        currentProject = currentProject!.copyWith(
          logicalComponents: newLogicalComponents,
          schematic: newSchematic,
        );
        _draggingComponent = null;
      });
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
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      setState(() {
        currentProject = projectFromJson(jsonDecode(content));
        _currentImageIndex = 0;
      });
    }
  }

  Future<void> _exportNetlist() async {
    if (currentProject == null) return;
    final netlist = generateNetlistFromProject(currentProject!);
    // Further export logic would go here
    print(netlist);
  }
}
