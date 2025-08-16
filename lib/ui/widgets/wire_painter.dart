import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pcb_rev/models/logical_models.dart';
import 'package:pcb_rev/models/project.dart';

class WirePainter extends CustomPainter {
  final Project project;
  final LogicalNet? selectedNet;

  WirePainter({required this.project, this.selectedNet});

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final netPaint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final wire in project.schematic.wires.values) {
      final logicalNet = project.logicalNets[wire.logicalNetId];

      bool isSelected = logicalNet != null && logicalNet == selectedNet;

      if (isSelected) {
        netPaint.color = Colors.yellow;
        netPaint.strokeWidth = 3.0;
      } else {
        netPaint.strokeWidth = 2.0;
        if (logicalNet != null) {
          if (logicalNet.name == 'VCC' || logicalNet.name == 'VDD') {
            netPaint.color = Colors.red;
          } else if (logicalNet.name == 'GND' || logicalNet.name == 'VSS') {
            netPaint.color = Colors.blue[800]!;
          } else {
            netPaint.color = Colors.green;
          }
        } else {
          netPaint.color = Colors.green;
        }
      }

      final positions = wire.points.map((p) => Offset(p.x, p.y)).toList();

      if (positions.length >= 2) {
        final path = Path();
        path.moveTo(positions.first.dx, positions.first.dy);

        for (int i = 1; i < positions.length; i++) {
          path.lineTo(positions[i].dx, positions[i].dy);
        }

        canvas.drawPath(path, netPaint);
      }

      final junctionPaint = Paint()
        ..color = netPaint.color
        ..style = PaintingStyle.fill;

      for (final pos in positions) {
        canvas.drawCircle(pos, 3, junctionPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WirePainter oldDelegate) {
    return oldDelegate.project != project || oldDelegate.selectedNet != selectedNet;
  }
}
