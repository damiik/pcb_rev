import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_models.dart';
import 'kicad_schematic_renderer.dart';
import 'kicad_symbol_renderer.dart';

class SchematicView extends StatefulWidget {
  final KiCadSchematic schematic;
  final Position? centerOn;
  final String? selectedSymbolId;
  final void Function(SymbolInstance)? onSymbolSelected;

  const SchematicView(
      {Key? key,
      required this.schematic,
      this.centerOn,
      this.selectedSymbolId,
      this.onSymbolSelected})
      : super(key: key);

  @override
  _SchematicViewState createState() => _SchematicViewState();
}

class _SchematicViewState extends State<SchematicView> {
  Map<String, Symbol>? _symbolCache;
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _loadSymbols();
  }

  @override
  void didUpdateWidget(covariant SchematicView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schematic != oldWidget.schematic) {
      _loadSymbols();
    }
    if (widget.centerOn != null && widget.centerOn != oldWidget.centerOn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnPosition(widget.centerOn!);
      });
    }
  }

  void _centerOnPosition(Position position) {
    final screenSize = context.size;
    if (screenSize == null) return;

    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    final schematicCenterPx = Offset(
      position.x * kicadUnitToPx,
      position.y * kicadUnitToPx,
    );

    final screenCenterPx = Offset(screenSize.width / 2, screenSize.height / 2);

    final translation = screenCenterPx - (schematicCenterPx * currentScale);

    final matrix = Matrix4.identity()
      ..translate(translation.dx, translation.dy)
      ..scale(currentScale);

    _transformationController.value = matrix;
  }

  void _loadSymbols() {
    if (widget.schematic.library == null) {
      setState(() {
        _symbolCache = {};
      });
      return;
    }
    final cache = <String, Symbol>{};
    for (final symbol in widget.schematic.library!.symbols) {
      cache[symbol.name] = symbol;
    }
    setState(() {
      _symbolCache = cache;
    });
  }

  void _handleTap(TapUpDetails details) {
    if (_symbolCache == null) return;

    final localPosition = details.localPosition;
    final localPositionVector = Vector4(localPosition.dx, localPosition.dy, 0, 1);
    final transformedPoint = Matrix4.inverted(_transformationController.value).transform(localPositionVector);
    final tapPosition = Offset(transformedPoint.x / kicadUnitToPx, transformedPoint.y / kicadUnitToPx);

    final renderer = KiCadSymbolRenderer();

    for (final symbolInstance in widget.schematic.symbols) {
      final symbol = _symbolCache![symbolInstance.libId];
      if (symbol != null) {
        final bounds = renderer.getSymbolBounds(symbol);
        final symbolRect = Rect.fromLTWH(
          symbolInstance.at.x + bounds.left,
          symbolInstance.at.y - bounds.bottom, // Y is inverted in symbol space
          bounds.width,
          bounds.height,
        );

        if (symbolRect.contains(tapPosition)) {
          widget.onSymbolSelected?.call(symbolInstance);
          return; // Stop after finding the first symbol
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_symbolCache == null) {
      return Center(child: CircularProgressIndicator());
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      constrained: false, // Allow panning beyond screen limits
      boundaryMargin: EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 10.0,
      child: GestureDetector(
        onTapUp: _handleTap,
        child: CustomPaint(
          size: Size(2000, 1500), // A large canvas for the schematic
          painter: _SchematicPainter(
            schematic: widget.schematic,
            symbolCache: _symbolCache!,
            selectedSymbolId: widget.selectedSymbolId,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}

class _SchematicPainter extends CustomPainter {
  final KiCadSchematic schematic;
  final Map<String, Symbol> symbolCache;
  final String? selectedSymbolId;

  _SchematicPainter(
      {required this.schematic,
      required this.symbolCache,
      this.selectedSymbolId});

  @override
  void paint(Canvas canvas, Size size) {
    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.grey[850]!,
    );

    final schematicRenderer = KiCadSchematicRenderer(symbolCache, selectedSymbolId: selectedSymbolId);
    schematicRenderer.render(canvas, size, schematic);
  }

  @override
  bool shouldRepaint(_SchematicPainter oldDelegate) {
    return oldDelegate.schematic != schematic ||
        oldDelegate.symbolCache != symbolCache ||
        oldDelegate.selectedSymbolId != selectedSymbolId;
  }
}
