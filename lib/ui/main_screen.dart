import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/image_modification.dart';
import '../models/pcb_board.dart';
import '../models/pcb_models.dart';
import '../services/image_processor.dart';
import '../services/mcp_server.dart';
import '../services/measurement_service.dart';
import 'widgets/component_list_panel.dart';
import 'widgets/pcb_viewer_panel.dart';
import 'widgets/properties_panel.dart';

class PCBAnalyzerApp extends StatefulWidget {
  @override
  _PCBAnalyzerAppState createState() => _PCBAnalyzerAppState();
}

class _PCBAnalyzerAppState extends State<PCBAnalyzerApp> {
  PCBBoard? currentBoard;
  int _currentIndex = 0;
  final MeasurementService measurementService = MeasurementService();
  final ImageProcessor imageProcessor = ImageProcessor();
  final MCPServer mcpServer = MCPServer(baseUrl: 'http://localhost:8080');

  @override
  void initState() {
    super.initState();
    currentBoard = PCBBoard(id: '1', name: 'My Board');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCB Reverse Engineering',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: Text('PCB Analyzer'),
          actions: [
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveProject,
            ),
            IconButton(
              icon: Icon(Icons.folder_open),
              onPressed: _openProject,
            ),
            IconButton(
              icon: Icon(Icons.share),
              onPressed: _exportNetlist,
            ),
          ],
        ),
        body: Row(
          children: [
            // Left panel - Component list
            Expanded(
              flex: 2,
              child: ComponentListPanel(
                components: currentBoard?.components.values.toList() ?? [],
                onComponentSelected: _selectComponent,
              ),
            ),

            // Center - PCB Viewer
            Expanded(
              flex: 5,
              child: PCBViewerPanel(
                board: currentBoard,
                currentIndex: _currentIndex,
                onImageDrop: _handleImageDrop,
                onNext: () {
                  setState(() {
                    if (currentBoard != null && _currentIndex < currentBoard!.images.length - 1) {
                      _currentIndex++;
                    }
                  });
                },
                onPrevious: () {
                  setState(() {
                    if (_currentIndex > 0) {
                      _currentIndex--;
                    }
                  });
                },
                onImageModification: _updateImageModification,
              ),
            ),

            // Right panel - Properties & Measurements
            Expanded(
              flex: 3,
              child: PropertiesPanel(
                measurementService: measurementService,
                onMeasurementAdded: _addMeasurement,
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.camera_alt),
          onPressed: _captureImage,
        ),
      ),
    );
  }

  void _selectComponent(Component component) {
    // Handle component selection
    setState(() {
      // Update UI to highlight selected component
    });
  }

  Future<void> _handleImageDrop(List<String> imagePaths) async {
    // Process dropped images
    for (final path in imagePaths) {
      final enhanced = await imageProcessor.enhanceImage(path);

      // Send to AI for analysis
      if (currentBoard != null) {
        final analysis = await mcpServer.analyzeImage(enhanced, currentBoard!);

        // Update board with AI findings
        setState(() {
          _updateBoardFromAnalysis(analysis);
          final newImage = PCBImage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            path: enhanced,
            layer: 'top', // or get from user
            type: ImageType.components, // or get from user
          );
          currentBoard!.images.insert(_currentIndex, newImage);
          currentBoard!.imageModifications[newImage.id] = ImageModification();
        });
      }
    }
  }

  void _updateBoardFromAnalysis(Map<String, dynamic> analysis) {
    // Parse AI response and update board state
    // Add new components, connections, etc.
  }

  void _addMeasurement(String type, dynamic value) {
    // Add measurement to service
    setState(() {
      // Update UI
    });
  }

  void _updateImageModification(ImageModification mod) {
    setState(() {
      final imageId = currentBoard!.images[_currentIndex].id;
      currentBoard!.imageModifications[imageId] = mod;
    });
  }

  Future<void> _captureImage() async {
    // Open camera or file picker
  }

  Future<void> _saveProject() async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'project.pcbrev',
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsString(jsonEncode(currentBoard?.toJson()));
    }
  }

  Future<void> _openProject() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      setState(() {
        currentBoard = PCBBoard.fromJson(jsonDecode(content));
        _currentIndex = 0;
      });
    }
  }

  Future<void> _exportNetlist() async {
    // Export netlist in various formats
  }
}
