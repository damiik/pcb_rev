import 'package:flutter/material.dart';
import '../data/kicad_schematic_models.dart';
import 'kicad_schematic_renderer.dart';

class SchematicView extends StatelessWidget {
  final KiCadSchematic schematic;

  const SchematicView({Key? key, required this.schematic}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      constrained: false, // Allow panning beyond screen limits
      boundaryMargin: EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 10.0,
      child: CustomPaint(
        size: Size(2000, 1500), // A large canvas for the schematic
        painter: _SchematicPainter(schematic: schematic),
      ),
    );
  }
}

class _SchematicPainter extends CustomPainter {
  final KiCadSchematic schematic;

  _SchematicPainter({required this.schematic});

  @override
  void paint(Canvas canvas, Size size) {
    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    final renderer = KiCadSchematicRenderer();
    renderer.render(canvas, size, schematic);
  }

  @override
  bool shouldRepaint(_SchematicPainter oldDelegate) {
    return oldDelegate.schematic != schematic;
  }
}
