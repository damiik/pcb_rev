import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/image_modification.dart';
import '../models/pcb_board.dart';
import '../models/pcb_models.dart';
import '../services/image_processor.dart';
import '../services/mcp_server.dart';
import '../services/measurement_service.dart';

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

class ComponentListPanel extends StatelessWidget {
  final List<Component> components;
  final Function(Component) onComponentSelected;

  ComponentListPanel({
    required this.components,
    required this.onComponentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey)),
      ),
      child: ListView.builder(
        itemCount: components.length,
        itemBuilder: (context, index) {
          final component = components[index];
          return ListTile(
            title: Text(component.id),
            subtitle: Text('${component.type} ${component.value ?? ""}'),
            onTap: () => onComponentSelected(component),
          );
        },
      ),
    );
  }
}

class PCBViewerPanel extends StatelessWidget {
  final PCBBoard? board;
  final Function(List<String>) onImageDrop;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(ImageModification) onImageModification;

  PCBViewerPanel({
    this.board,
    required this.onImageDrop,
    required this.currentIndex,
    required this.onNext,
    required this.onPrevious,
    required this.onImageModification,
  });

  @override
  Widget build(BuildContext context) {
    final imageMod = (board != null && board!.images.isNotEmpty)
        ? board!.imageModifications[board!.images[currentIndex].id] ?? ImageModification()
        : ImageModification();

    return DropTarget(
      onDragDone: (details) {
        onImageDrop(details.files.map((f) => f.path).toList());
      },
      child: Container(
        color: Colors.black,
        child: board == null || board!.images.isEmpty
            ? Center(
                child: Text(
                  'Drop PCB images here',
                  style: TextStyle(color: Colors.grey, fontSize: 24),
                ),
              )
            : Stack(
                children: [
                  // Display PCB images with annotations
                  if (board!.images.isNotEmpty)
                    Center(
                      child: Transform.rotate(
                        angle: imageMod.rotation * math.pi / 180,
                        child: Transform(
                          transform: Matrix4.identity()
                            ..rotateY(imageMod.flipHorizontal ? math.pi : 0)
                            ..rotateX(imageMod.flipVertical ? math.pi : 0),
                          alignment: Alignment.center,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix([
                              // Contrast
                              imageMod.contrast + 1, 0, 0, 0, 0,
                              0, imageMod.contrast + 1, 0, 0, 0,
                              0, 0, imageMod.contrast + 1, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.matrix([
                                // Brightness
                                1, 0, 0, 0, imageMod.brightness * 255,
                                0, 1, 0, 0, imageMod.brightness * 255,
                                0, 1, 0, 0, imageMod.brightness * 255,
                                0, 0, 0, 1, 0,
                              ]),
                              child: ColorFiltered(
                                colorFilter: ColorFilter.matrix([
                                  // Invert
                                  imageMod.invertColors ? -1 : 1, 0, 0, 0, imageMod.invertColors ? 255 : 0,
                                  0, imageMod.invertColors ? -1 : 1, 0, 0, imageMod.invertColors ? 255 : 0,
                                  0, 0, imageMod.invertColors ? -1 : 1, 0, imageMod.invertColors ? 255 : 0,
                                  0, 0, 0, 1, 0,
                                ]),
                                child: Image.file(File(board!.images[currentIndex].path)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Overlay component markers
                  ...board!.components.values.map((comp) {
                    return Positioned(
                      left: comp.position.x,
                      top: comp.position.y,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        color: Colors.blue.withOpacity(0.3),
                        child: Text(
                          comp.id,
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    );
                  }),
                  // Navigation buttons
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: onPrevious,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: IconButton(
                      icon: Icon(Icons.arrow_forward),
                      onPressed: onNext,
                    ),
                  ),
                  // Modification controls
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        IconButton(
                          icon: Icon(Icons.rotate_left),
                          onPressed: () {
                            imageMod.rotation -= 90;
                            onImageModification(imageMod);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.rotate_right),
                          onPressed: () {
                            imageMod.rotation += 90;
                            onImageModification(imageMod);
                          },
                        ),
                        IconButton(
                          icon: Column(
                            children: [
                              Icon(Icons.flip),
                              Text("Horizontal"),
                            ],
                          ),
                          onPressed: () {
                            imageMod.flipHorizontal = !imageMod.flipHorizontal;
                            onImageModification(imageMod);
                          },
                        ),
                        IconButton(
                          icon: Column(
                            children: [
                              Icon(Icons.flip),
                              Text("Vertical"),
                            ],
                          ),
                          onPressed: () {
                            imageMod.flipVertical = !imageMod.flipVertical;
                            onImageModification(imageMod);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.invert_colors),
                          onPressed: () {
                            imageMod.invertColors = !imageMod.invertColors;
                            onImageModification(imageMod);
                          },
                        ),
                        Text("Contrast"),
                        Slider(
                          value: imageMod.contrast,
                          min: -1,
                          max: 1,
                          onChanged: (value) {
                            imageMod.contrast = value;
                            onImageModification(imageMod);
                          },
                        ),
                        Text("Brightness"),
                        Slider(
                          value: imageMod.brightness,
                          min: -1,
                          max: 1,
                          onChanged: (value) {
                            imageMod.brightness = value;
                            onImageModification(imageMod);
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
      ),
    );
  }
}

class PropertiesPanel extends StatelessWidget {
  final MeasurementService measurementService;
  final Function(String, dynamic) onMeasurementAdded;

  PropertiesPanel({
    required this.measurementService,
    required this.onMeasurementAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey)),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Measurements', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          
          // Measurement input forms
          ElevatedButton.icon(
            icon: Icon(Icons.electrical_services),
            label: Text('Add Resistance'),
            onPressed: () => _showMeasurementDialog(context, 'resistance'),
          ),
          
          SizedBox(height: 8),
          
          ElevatedButton.icon(
            icon: Icon(Icons.flash_on),
            label: Text('Add Voltage'),
            onPressed: () => _showMeasurementDialog(context, 'voltage'),
          ),
          
          SizedBox(height: 8),
          
          ElevatedButton.icon(
            icon: Icon(Icons.link),
            label: Text('Test Continuity'),
            onPressed: () => _showMeasurementDialog(context, 'continuity'),
          ),
          
          Divider(height: 32),
          
          // Display recent measurements
          Expanded(
            child: ListView(
              children: [
                ...measurementService.resistanceMap.entries.map((e) {
                  return ListTile(
                    leading: Icon(Icons.electrical_services),
                    title: Text(e.key),
                    trailing: Text('${e.value} Ω'),
                  );
                }),
                ...measurementService.voltageMap.entries.map((e) {
                  return ListTile(
                    leading: Icon(Icons.flash_on),
                    title: Text(e.key),
                    trailing: Text('${e.value} V'),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMeasurementDialog(BuildContext context, String type) {
    // Show dialog to input measurement
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $type measurement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Point 1'),
            ),
            if (type != 'voltage')
              TextField(
                decoration: InputDecoration(labelText: 'Point 2'),
              ),
            TextField(
              decoration: InputDecoration(labelText: 'Value'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Add'),
            onPressed: () {
              // Add measurement
              onMeasurementAdded(type, 0); // Pass actual values
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}