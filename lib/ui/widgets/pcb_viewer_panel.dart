import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import '../../models/image_modification.dart';
import '../../models/pcb_board.dart';

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
