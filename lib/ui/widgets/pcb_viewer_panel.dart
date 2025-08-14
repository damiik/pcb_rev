// lib/ui/widgets/pcb_viewer_panel.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../models/image_modification.dart';
import '../../models/pcb_board.dart';
import '../../models/pcb_models.dart';

class PCBViewerPanel extends StatefulWidget {
  final PCBBoard? board;
  final int currentIndex;
  final Function(List<String>) onImageDrop;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(ImageModification) onImageModification;

  PCBViewerPanel({
    this.board,
    required this.currentIndex,
    required this.onImageDrop,
    required this.onNext,
    required this.onPrevious,
    required this.onImageModification,
  });

  @override
  _PCBViewerPanelState createState() => _PCBViewerPanelState();
}

class _PCBViewerPanelState extends State<PCBViewerPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TransformationController _transformController = TransformationController();
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
    _currentModification =
        widget.board?.imageModifications[widget
            .board
            ?.images[widget.currentIndex]
            .id] ??
        ImageModification();
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
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 0.1,
      maxScale: 10.0,
      child: Stack(
        children: [
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
                showComponents: _showComponents,
                showNets: _showNets,
                selectedComponent: _selectedComponent,
                selectedNet: _selectedNet,
              ),
            ),

          // Interactive overlay
          if (_showAnnotations) _buildInteractiveOverlay(),
        ],
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

// Grid painter for schematic view
class GridPainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 0.5;

    const gridSize = 20.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Schematic renderer
class SchematicPainter extends CustomPainter {
  final PCBBoard board;
  final bool showComponents;
  final bool showNets;
  final Component? selectedComponent;
  final Net? selectedNet;

  SchematicPainter({
    required this.board,
    required this.showComponents,
    required this.showNets,
    this.selectedComponent,
    this.selectedNet,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Draw nets (connections) first
    if (showNets) {
      _drawNets(canvas);
    }

    // Draw components on top
    if (showComponents) {
      _drawComponents(canvas);
    }
  }

  void _drawNets(ui.Canvas canvas) {
    final netPaint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final net in board.nets.values) {
      // Set color based on net type and selection
      if (net == selectedNet) {
        netPaint.color = Colors.yellow;
        netPaint.strokeWidth = 3.0;
      } else if (net.name == 'VCC' || net.name == 'VDD') {
        netPaint.color = Colors.red;
      } else if (net.name == 'GND' || net.name == 'VSS') {
        netPaint.color = Colors.black;
      } else {
        netPaint.color = Colors.green;
      }

      // Draw connections between pins
      final positions = <Offset>[];
      for (final connection in net.connections) {
        final component = board.components[connection.componentId];
        if (component != null) {
          final pin = component.pins[connection.pinId];
          if (pin != null) {
            positions.add(Offset(pin.position.x, pin.position.y));
          }
        }
      }

      // Draw lines between connected pins
      if (positions.length >= 2) {
        final path = Path();
        path.moveTo(positions.first.dx, positions.first.dy);

        // Use Manhattan routing for more PCB-like appearance
        for (int i = 1; i < positions.length; i++) {
          final current = positions[i - 1];
          final next = positions[i];

          // Draw L-shaped connection
          path.lineTo(next.dx, current.dy);
          path.lineTo(next.dx, next.dy);
        }

        canvas.drawPath(path, netPaint);
      }

      // Draw junction dots at connection points
      final junctionPaint = Paint()
        ..color = netPaint.color
        ..style = PaintingStyle.fill;

      for (final pos in positions) {
        canvas.drawCircle(pos, 3, junctionPaint);
      }
    }
  }

  void _drawComponents(ui.Canvas canvas) {
    for (final component in board.components.values) {
      _drawComponent(canvas, component);
    }
  }

  void _drawComponent(ui.Canvas canvas, Component component) {
    final isSelected = component == selectedComponent;
    final paint = Paint()
      ..color = isSelected ? Colors.blue : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.0;

    final fillPaint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.fill;

    final pos = Offset(component.position.x, component.position.y);

    // Draw component based on type
    switch (component.type.toLowerCase()) {
      case 'resistor':
        _drawResistor(canvas, pos, paint, fillPaint);
        break;
      case 'capacitor':
        _drawCapacitor(canvas, pos, paint, fillPaint);
        break;
      case 'ic':
      case 'chip':
        _drawIC(canvas, pos, component, paint, fillPaint);
        break;
      case 'inductor':
        _drawInductor(canvas, pos, paint, fillPaint);
        break;
      case 'diode':
        _drawDiode(canvas, pos, paint, fillPaint);
        break;
      case 'transistor':
        _drawTransistor(canvas, pos, paint, fillPaint);
        break;
      default:
        _drawGenericComponent(canvas, pos, paint, fillPaint);
    }

    // Draw component label
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${component.id}\n${component.value ?? ""}',
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white70,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(canvas, pos + Offset(-textPainter.width / 2, 20));

    // Draw pins
    final pinPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    for (final pin in component.pins.values) {
      final pinPos = Offset(pin.position.x, pin.position.y);
      canvas.drawCircle(pinPos, 2, pinPaint);

      // Draw pin labels if component is selected
      if (isSelected && pin.function != null) {
        final pinTextPainter = TextPainter(
          text: TextSpan(
            text: pin.function,
            style: TextStyle(color: Colors.orange, fontSize: 8),
          ),
          textDirection: TextDirection.ltr,
        );
        pinTextPainter.layout();
        pinTextPainter.paint(canvas, pinPos + Offset(3, -10));
      }
    }
  }

  void _drawResistor(
    ui.Canvas canvas,
    Offset pos,
    Paint paint,
    Paint fillPaint,
  ) {
    final rect = Rect.fromCenter(center: pos, width: 30, height: 10);
    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, paint);
  }

  void _drawCapacitor(
    ui.Canvas canvas,
    Offset pos,
    Paint paint,
    Paint fillPaint,
  ) {
    canvas.drawLine(pos + Offset(-5, -10), pos + Offset(-5, 10), paint);
    canvas.drawLine(pos + Offset(5, -10), pos + Offset(5, 10), paint);
  }

  void _drawIC(
    ui.Canvas canvas,
    Offset pos,
    Component component,
    Paint paint,
    Paint fillPaint,
  ) {
    final pinCount = component.pins.length;
    final width = 40.0;
    final height = math.max(20.0, pinCount * 5.0);

    final rect = Rect.fromCenter(center: pos, width: width, height: height);
    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, paint);

    // Draw notch
    canvas.drawCircle(pos + Offset(-width / 2, 0), 3, paint);
  }

  void _drawInductor(
    ui.Canvas canvas,
    Offset pos,
    Paint paint,
    Paint fillPaint,
  ) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final x = pos.dx - 15 + i * 10;
      path.addArc(
        Rect.fromCircle(center: Offset(x, pos.dy), radius: 5),
        math.pi,
        math.pi,
      );
    }
    canvas.drawPath(path, paint);
  }

  void _drawDiode(ui.Canvas canvas, Offset pos, Paint paint, Paint fillPaint) {
    final path = Path();
    path.moveTo(pos.dx - 10, pos.dy - 8);
    path.lineTo(pos.dx + 10, pos.dy);
    path.lineTo(pos.dx - 10, pos.dy + 8);
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
    canvas.drawLine(pos + Offset(10, -8), pos + Offset(10, 8), paint);
  }

  void _drawTransistor(
    ui.Canvas canvas,
    Offset pos,
    Paint paint,
    Paint fillPaint,
  ) {
    canvas.drawCircle(pos, 15, fillPaint);
    canvas.drawCircle(pos, 15, paint);

    // Draw base
    canvas.drawLine(pos + Offset(-15, 0), pos + Offset(-5, 0), paint);
    canvas.drawLine(pos + Offset(-5, -8), pos + Offset(-5, 8), paint);

    // Draw collector and emitter
    canvas.drawLine(pos + Offset(-5, -4), pos + Offset(5, -10), paint);
    canvas.drawLine(pos + Offset(-5, 4), pos + Offset(5, 10), paint);
  }

  void _drawGenericComponent(
    ui.Canvas canvas,
    Offset pos,
    Paint paint,
    Paint fillPaint,
  ) {
    final rect = Rect.fromCenter(center: pos, width: 30, height: 20);
    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant SchematicPainter oldDelegate) {
    return oldDelegate.selectedComponent != selectedComponent ||
        oldDelegate.selectedNet != selectedNet ||
        oldDelegate.showComponents != showComponents ||
        oldDelegate.showNets != showNets;
  }
}
