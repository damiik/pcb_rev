import 'package:flutter/material.dart';
import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_models.dart';
import 'kicad_schematic_renderer.dart';

class SchematicView extends StatefulWidget {
  final KiCadSchematic schematic;

  const SchematicView({Key? key, required this.schematic}) : super(key: key);

  @override
  _SchematicViewState createState() => _SchematicViewState();
}

class _SchematicViewState extends State<SchematicView> {
  Map<String, Symbol>? _symbolCache;

  @override
  void initState() {
    super.initState();
    _loadSymbols();
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

  @override
  Widget build(BuildContext context) {
    if (_symbolCache == null) {
      return Center(child: CircularProgressIndicator());
    }

    return InteractiveViewer(
      constrained: false, // Allow panning beyond screen limits
      boundaryMargin: EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 10.0,
      child: CustomPaint(
        size: Size(2000, 1500), // A large canvas for the schematic
        painter: _SchematicPainter(
          schematic: widget.schematic,
          symbolCache: _symbolCache!,
        ),
      ),
    );
  }
}

class _SchematicPainter extends CustomPainter {
  final KiCadSchematic schematic;
  final Map<String, Symbol> symbolCache;

  _SchematicPainter({required this.schematic, required this.symbolCache});

  @override
  void paint(Canvas canvas, Size size) {
    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.grey[850]!,
    );

    final renderer = KiCadSchematicRenderer(symbolCache);
    renderer.render(canvas, size, schematic);
  }

  @override
  bool shouldRepaint(_SchematicPainter oldDelegate) {
    return oldDelegate.schematic != schematic ||
        oldDelegate.symbolCache != symbolCache;
  }
}
