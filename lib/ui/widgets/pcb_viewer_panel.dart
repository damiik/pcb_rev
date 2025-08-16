import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pcb_rev/models/project.dart';
import '../../models/image_modification.dart';
import '../../models/logical_models.dart';
import '../../models/visual_models.dart';
import 'schematic_painter.dart';
import 'wire_painter.dart';

class PCBViewerPanel extends StatefulWidget {
  final Project? project;
  final bool isProcessingImage;
  final LogicalComponent? draggingComponent;
  final int currentIndex;
  final Function(List<String>) onImageDrop;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(ImageModification) onImageModification;
  final Function(Offset)? onTap;

  PCBViewerPanel({
    this.project,
    this.isProcessingImage = false,
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
  final TransformationController _transformController =
      TransformationController();
  Offset? _mousePosition;
  ViewMode _viewMode = ViewMode.schematic;
  bool _showGrid = true;
  bool _snapToGrid = true;
  bool _showComponents = true;
  bool _showNets = true;
  Symbol? _selectedSymbol;
  LogicalNet? _selectedNet;

  ImageModification get _currentModification {
    if (widget.project != null && widget.project!.pcbImages.isNotEmpty) {
      return widget.project!.pcbImages[widget.currentIndex].modification;
    }
    return createDefaultImageModification();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.project == null ||
                    (_viewMode == ViewMode.image &&
                        widget.project!.pcbImages.isEmpty))
                  Text(
                    'Drop PCB images here',
                    style: TextStyle(color: Colors.grey, fontSize: 24),
                  )
                else
                  _buildViewer(),
                if (widget.isProcessingImage)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 48,
      color: Colors.grey[900],
      child: Row(
        children: [
          ToggleButtons(
            children: [
              Tooltip(child: Icon(Icons.image), message: 'Image View'),
              Tooltip(child: Icon(Icons.schema), message: 'Schematic View'),
            ],
            isSelected: [
              _viewMode == ViewMode.image,
              _viewMode == ViewMode.schematic,
            ],
            onPressed: (index) =>
                setState(() => _viewMode = ViewMode.values[index]),
          ),
          if (_viewMode == ViewMode.schematic) ...[
            SizedBox(width: 16),
            IconButton(
              icon: Icon(Icons.grid_on),
              color: _showGrid ? Colors.blue : Colors.grey,
              onPressed: () => setState(() => _showGrid = !_showGrid),
              tooltip: 'Toggle Grid',
            ),
            IconButton(
              icon: Icon(Icons.gps_fixed),
              color: _snapToGrid ? Colors.blue : Colors.grey,
              onPressed: () => setState(() => _snapToGrid = !_snapToGrid),
              tooltip: 'Snap to Grid',
            ),
            IconButton(
              icon: Icon(Icons.electrical_services),
              color: _showNets ? Colors.blue : Colors.grey,
              onPressed: () => setState(() => _showNets = !_showNets),
              tooltip: 'Show Nets',
            ),
          ],
          Spacer(),
          if (_viewMode == ViewMode.image &&
              widget.project!.pcbImages.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: widget.currentIndex > 0 ? widget.onPrevious : null,
            ),
            Text(
              '${widget.currentIndex + 1} / ${widget.project!.pcbImages.length}',
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed:
                  widget.currentIndex < widget.project!.pcbImages.length - 1
                  ? widget.onNext
                  : null,
            ),
            IconButton(
              icon: Icon(Icons.tune),
              onPressed: _showImageAdjustments,
              tooltip: 'Image Adjustments',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewer() {
    return Listener(
      onPointerMove: (event) {
        if (widget.draggingComponent != null) {
          setState(() {
            var localPosition = _transformController.toScene(event.localPosition);
            if (_snapToGrid) {
              const gridSize = 20.0;
              localPosition = Offset(
                (localPosition.dx / gridSize).round() * gridSize,
                (localPosition.dy / gridSize).round() * gridSize,
              );
            }
            _mousePosition = localPosition;
          });
        }
      },
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.1,
        maxScale: 10.0,
        child: GestureDetector(
          onTapUp: (details) {
            if (widget.onTap != null) {
              final localPosition = _transformController.toScene(
                details.localPosition,
              );
              widget.onTap!(localPosition);
            }
          },
          child: Stack(
            children: <Widget>[
              if (_viewMode == ViewMode.schematic && _showGrid)
                CustomPaint(
                  size: const ui.Size(double.infinity, double.infinity),
                  painter: GridPainter(),
                ),
              if (_viewMode == ViewMode.schematic && _showNets)
                CustomPaint(
                  size: const ui.Size(double.infinity, double.infinity),
                  painter: WirePainter(
                    project: widget.project!,
                    selectedNet: _selectedNet,
                  ),
                ),
              if (_viewMode == ViewMode.schematic)
                CustomPaint(
                  size: const ui.Size(double.infinity, double.infinity),
                  painter: SchematicPainter(
                    project: widget.project!,
                    draggingComponent: widget.draggingComponent,
                    mousePosition: _mousePosition,
                  ),
                ),
              if (_viewMode == ViewMode.image &&
                  widget.project!.pcbImages.isNotEmpty)
                _buildImageLayer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageLayer() {
    final imageView = widget.project!.pcbImages[widget.currentIndex];
    final mod = imageView.modification;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(mod.rotation * math.pi / 180)
        ..scale(mod.flipHorizontal ? -1.0 : 1.0, mod.flipVertical ? -1.0 : 1.0),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(_getColorMatrix(mod)),
        child: Image.file(File(imageView.path), fit: BoxFit.contain),
      ),
    );
  }

  List<double> _getColorMatrix(ImageModification mod) {
    final b = mod.brightness;
    final c = mod.contrast + 1;
    if (mod.invertColors) {
      return [
        -c,
        0,
        0,
        0,
        255,
        0,
        -c,
        0,
        0,
        255,
        0,
        0,
        -c,
        0,
        255,
        0,
        0,
        0,
        1,
        0,
      ];
    }
    return [
      c,
      0,
      0,
      0,
      b * 255,
      0,
      c,
      0,
      0,
      b * 255,
      0,
      0,
      c,
      0,
      b * 255,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      color: Colors.grey[900],
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (_selectedSymbol != null)
            Text('Selected: ${_selectedSymbol!.logicalComponentId}'),
          Spacer(),
          Text(
            'Zoom: ${(_transformController.value.getMaxScaleOnAxis() * 100).toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }

  void _showImageAdjustments() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Image Adjustments'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSlider(
                    context,
                    'Rotation',
                    _currentModification.rotation,
                    -180,
                    180,
                    (v) {
                      setState(() {
                        widget.onImageModification(
                          _currentModification.copyWith(rotation: v),
                        );
                      });
                    },
                  ),
                  _buildSlider(
                    context,
                    'Brightness',
                    _currentModification.brightness,
                    -1,
                    1,
                    (v) {
                      setState(() {
                        widget.onImageModification(
                          _currentModification.copyWith(brightness: v),
                        );
                      });
                    },
                  ),
                  _buildSlider(
                    context,
                    'Contrast',
                    _currentModification.contrast,
                    -1,
                    1,
                    (v) {
                      setState(() {
                        widget.onImageModification(
                          _currentModification.copyWith(contrast: v),
                        );
                      });
                    },
                  ),
                  _buildSwitch(
                    context,
                    'Flip Horizontal',
                    _currentModification.flipHorizontal,
                    (v) {
                      setState(() {
                        widget.onImageModification(
                          _currentModification.copyWith(flipHorizontal: v),
                        );
                      });
                    },
                  ),
                  _buildSwitch(
                    context,
                    'Flip Vertical',
                    _currentModification.flipVertical,
                    (v) {
                      setState(() {
                        widget.onImageModification(
                          _currentModification.copyWith(flipVertical: v),
                        );
                      });
                    },
                  ),
                  _buildSwitch(
                    context,
                    'Invert Colors',
                    _currentModification.invertColors,
                    (v) {
                      setState(() {
                        widget.onImageModification(
                          _currentModification.copyWith(invertColors: v),
                        );
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            child: Text('Reset'),
            onPressed: () {
              setState(() {
                widget.onImageModification(createDefaultImageModification());
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

  Widget _buildSlider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return ListTile(
      title: Text('$label: ${value.toStringAsFixed(2)}'),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSwitch(
    BuildContext context,
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

enum ViewMode { image, schematic }
