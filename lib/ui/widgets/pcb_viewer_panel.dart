// lib/ui/widgets/pcb_viewer_panel.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../models/image_modification.dart';
import '../../models/pcb_board.dart';
import '../../models/pcb_models.dart';
import 'schematic_painter.dart';

class PCBViewerPanel extends StatefulWidget {
  final PCBBoard? board;
  final Component? draggingComponent;
  final int currentIndex;
  final Function(List<String>) onImageDrop;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(ImageModification) onImageModification;
  final Function(Offset)? onTap;

  PCBViewerPanel({
    this.board,
    this.draggingComponent,
    required this.currentIndex,
    required this.onImageDrop,
    required this.onNext,
    required this.onPrevious,
    required this.onImageModification,
    this.onTap,
  });

  @override
  _PCBViewerPanelState createState() => _PCBViewerPanelState();
}

class _PCBViewerPanelState extends State<PCBViewerPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TransformationController _transformController = TransformationController();
  Offset? _mousePosition;
  ViewMode _viewMode = ViewMode.image;
  bool _showComponents = true;
  bool _showNets = true;
  bool _showAnnotations = true;
  Component? _selectedComponent;
  Net? _selectedNet;

  // Image modification controls
  late ImageModification _currentModification;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.board != null && widget.board!.images.isNotEmpty) {
      _currentModification =
          widget.board?.imageModifications[widget
              .board
              ?.images[widget.currentIndex]
              .id] ??
          ImageModification();
    } else {
      _currentModification = ImageModification();
    }
  }

  @override
  void didUpdateWidget(PCBViewerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.board != null && widget.board!.images.isNotEmpty) {
      final imageId = widget.board!.images[widget.currentIndex].id;
      _currentModification =
          widget.board!.imageModifications[imageId] ?? ImageModification();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Toolbar
          Container(
            height: 48,
            color: Colors.grey[900],
            child: Row(
              children: [
                // View mode selector
                ToggleButtons(
                  children: [
                    Tooltip(child: Icon(Icons.image), message: 'Image View'),
                    Tooltip(
                      child: Icon(Icons.schema),
                      message: 'Schematic View',
                    ),
                    Tooltip(
                      child: Icon(Icons.layers),
                      message: 'Combined View',
                    ),
                  ],
                  isSelected: [
                    _viewMode == ViewMode.image,
                    _viewMode == ViewMode.schematic,
                    _viewMode == ViewMode.combined,
                  ],
                  onPressed: (index) {
                    setState(() {
                      _viewMode = ViewMode.values[index];
                    });
                  },
                ),
                SizedBox(width: 16),

                // Layer toggles
                IconButton(
                  icon: Icon(Icons.memory),
                  color: _showComponents ? Colors.blue : Colors.grey,
                  onPressed: () =>
                      setState(() => _showComponents = !_showComponents),
                  tooltip: 'Toggle Components',
                ),
                IconButton(
                  icon: Icon(Icons.cable),
                  color: _showNets ? Colors.green : Colors.grey,
                  onPressed: () => setState(() => _showNets = !_showNets),
                  tooltip: 'Toggle Nets',
                ),
                IconButton(
                  icon: Icon(Icons.note),
                  color: _showAnnotations ? Colors.orange : Colors.grey,
                  onPressed: () =>
                      setState(() => _showAnnotations = !_showAnnotations),
                  tooltip: 'Toggle Annotations',
                ),

                Spacer(),

                // Navigation
                if (widget.board != null &&
                    widget.board!.images.isNotEmpty) ...[
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: widget.currentIndex > 0
                        ? widget.onPrevious
                        : null,
                  ),
                  Text(
                    '${widget.currentIndex + 1} / ${widget.board!.images.length}',
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward),
                    onPressed:
                        widget.currentIndex < widget.board!.images.length - 1
                        ? widget.onNext
                        : null,
                  ),
                ],

                // Image adjustments
                IconButton(
                  icon: Icon(Icons.tune),
                  onPressed: _showImageAdjustments,
                  tooltip: 'Image Adjustments',
                ),
              ],
            ),
          ),

          // Main viewer
          Expanded(
            child: widget.board == null ? _buildDropZone() : _buildViewer(),
          ),

          // Status bar
          Container(
            height: 24,
            color: Colors.grey[900],
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (_selectedComponent != null)
                  Text(
                    'Selected: ${_selectedComponent!.id} (${_selectedComponent!.type})',
                    style: TextStyle(fontSize: 12),
                  ),
                if (_selectedNet != null)
                  Text(
                    'Net: ${_selectedNet!.name}',
                    style: TextStyle(fontSize: 12),
                  ),
                Spacer(),
                Text(
                  'Zoom: ${(_transformController.value.getMaxScaleOnAxis() * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone() {
    return DragTarget<List<String>>(
      onAccept: widget.onImageDrop,
      builder: (context, candidateData, rejectedData) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Drop PCB images here',
                style: TextStyle(color: Colors.grey, fontSize: 24),
              ),
              SizedBox(height: 8),
              Text(
                'or click the camera button to capture',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewer() {
    return Listener(
      onPointerMove: (event) {
        if (widget.draggingComponent != null) {
          setState(() {
            _mousePosition = _transformController.toScene(event.localPosition);
          });
        }
      },
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.1,
        maxScale: 10.0,
        child: Stack(
          children: <Widget>[
            // Background grid
            if (_viewMode != ViewMode.image)
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: GridPainter(),
              ),

            // PCB Image layer
            if (_viewMode != ViewMode.schematic &&
                widget.board!.images.isNotEmpty)
              _buildImageLayer(),

            // Schematic rendering layer
            if (_viewMode != ViewMode.image)
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: SchematicPainter(
                  board: widget.board!,
                  draggingComponent: widget.draggingComponent,
                  mousePosition: _mousePosition,
                  showComponents: _showComponents,
                  showNets: _showNets,
                  selectedComponent: _selectedComponent,
                  selectedNet: _selectedNet,
                ),
              ),

            // Interactive overlay
            if (_showAnnotations) _buildInteractiveOverlay(),

            GestureDetector(
              onTapUp: (details) {
                if (widget.onTap != null) {
                  final localPosition = _transformController.toScene(
                    details.localPosition,
                  );
                  widget.onTap!(localPosition);
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageLayer() {
    final image = widget.board!.images[widget.currentIndex];
    final modification = _currentModification;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(modification.rotation * math.pi / 180)
        ..scale(
          modification.flipHorizontal ? -1.0 : 1.0,
          modification.flipVertical ? -1.0 : 1.0,
        ),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(_getColorMatrix(modification)),
        child: Image.file(File(image.path), fit: BoxFit.contain),
      ),
    );
  }

  List<double> _getColorMatrix(ImageModification mod) {
    final brightness = mod.brightness;
    final contrast = mod.contrast + 1;

    // Base matrix
    var matrix = <double>[
      contrast,
      0,
      0,
      0,
      brightness * 255,
      0,
      contrast,
      0,
      0,
      brightness * 255,
      0,
      0,
      contrast,
      0,
      brightness * 255,
      0,
      0,
      0,
      1,
      0,
    ];

    // Invert colors if needed
    if (mod.invertColors) {
      matrix = <double>[
        -1,
        0,
        0,
        0,
        255,
        0,
        -1,
        0,
        0,
        255,
        0,
        0,
        -1,
        0,
        255,
        0,
        0,
        0,
        1,
        0,
      ];
    }

    return matrix;
  }

  Widget _buildInteractiveOverlay() {
    return Stack(
      children: [
        // Component markers
        if (_showComponents)
          ...widget.board!.components.values.map((comp) {
            return Positioned(
              left: comp.position.x,
              top: comp.position.y,
              child: GestureDetector(
                onTap: () => setState(() => _selectedComponent = comp),
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _selectedComponent == comp
                        ? Colors.blue.withOpacity(0.5)
                        : Colors.blue.withOpacity(0.2),
                    border: Border.all(
                      color: _selectedComponent == comp
                          ? Colors.blue
                          : Colors.blue.withOpacity(0.5),
                      width: _selectedComponent == comp ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    comp.id,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),

        // Net indicators
        if (_showNets && _selectedNet != null)
          ...widget.board!.components.values.expand((comp) {
            return comp.pins.values
                .where((pin) => pin.netName == _selectedNet!.name)
                .map(
                  (pin) => Positioned(
                    left: pin.position.x - 3,
                    top: pin.position.y - 3,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
          }),
      ],
    );
  }

  void _showImageAdjustments() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Image Adjustments'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rotation
              ListTile(
                title: Text(
                  'Rotation: ${_currentModification.rotation.toStringAsFixed(0)}°',
                ),
                subtitle: Slider(
                  value: _currentModification.rotation,
                  min: -180,
                  max: 180,
                  onChanged: (value) {
                    setState(() {
                      _currentModification.rotation = value;
                      widget.onImageModification(_currentModification);
                    });
                  },
                ),
              ),

              // Brightness
              ListTile(
                title: Text(
                  'Brightness: ${(_currentModification.brightness * 100).toStringAsFixed(0)}%',
                ),
                subtitle: Slider(
                  value: _currentModification.brightness,
                  min: -1,
                  max: 1,
                  onChanged: (value) {
                    setState(() {
                      _currentModification.brightness = value;
                      widget.onImageModification(_currentModification);
                    });
                  },
                ),
              ),

              // Contrast
              ListTile(
                title: Text(
                  'Contrast: ${(_currentModification.contrast * 100).toStringAsFixed(0)}%',
                ),
                subtitle: Slider(
                  value: _currentModification.contrast,
                  min: -1,
                  max: 1,
                  onChanged: (value) {
                    setState(() {
                      _currentModification.contrast = value;
                      widget.onImageModification(_currentModification);
                    });
                  },
                ),
              ),

              // Flip controls
              SwitchListTile(
                title: Text('Flip Horizontal'),
                value: _currentModification.flipHorizontal,
                onChanged: (value) {
                  setState(() {
                    _currentModification.flipHorizontal = value;
                    widget.onImageModification(_currentModification);
                  });
                },
              ),

              SwitchListTile(
                title: Text('Flip Vertical'),
                value: _currentModification.flipVertical,
                onChanged: (value) {
                  setState(() {
                    _currentModification.flipVertical = value;
                    widget.onImageModification(_currentModification);
                  });
                },
              ),

              SwitchListTile(
                title: Text('Invert Colors'),
                value: _currentModification.invertColors,
                onChanged: (value) {
                  setState(() {
                    _currentModification.invertColors = value;
                    widget.onImageModification(_currentModification);
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Reset'),
            onPressed: () {
              setState(() {
                _currentModification = ImageModification();
                widget.onImageModification(_currentModification);
              });
            },
          ),
          ElevatedButton(
            child: Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transformController.dispose();
    super.dispose();
  }
}

enum ViewMode { image, schematic, combined }
