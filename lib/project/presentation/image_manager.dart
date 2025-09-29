import 'package:flutter/material.dart';
import '../data/project.dart';
import '../api/application_api.dart';
import '../../pcb_viewer/data/image_modification.dart';

/// Manages image-related operations like handling drops, navigation, and modifications
class ImageManager {
  final ApplicationAPI _applicationAPI;

  ImageManager(this._applicationAPI);

  /// Handle image drop from drag and drop
  Future<void> handleImageDrop(
    List<String> imagePaths,
    Project? currentProject,
    BuildContext context,
    Function(Project, int) onSuccess,
    VoidCallback onError,
  ) async {
    print('[ImageManager] Handling image drop with paths: $imagePaths');
    if (currentProject == null) {
      print('[ImageManager] Project is null. Aborting drop.');
      return;
    }

    try {
      var project = currentProject;
      for (final path in imagePaths) {
        print('[ImageManager] Processing path: $path');

        final enhancedPath = await _applicationAPI.processImage(path);
        print('[ImageManager] Enhanced image path: $enhancedPath');

        project = _applicationAPI.addImage(
          project: project,
          path: enhancedPath,
          layer: 'top',
        );
        print('[ImageManager] Added new image to project state.');
      }

      final newIndex = project.pcbImages.length - 1;
      onSuccess(project, newIndex);
    } catch (e) {
      print('[ImageManager] Error during image drop processing: $e');
      _showErrorSnackBar(context, 'Error processing images: $e');
      onError();
    }
  }

  /// Navigate between images
  void navigateImages(
    int delta,
    int currentIndex,
    Project? currentProject,
    Function(int) onIndexChanged,
  ) {
    if (currentProject == null) return;
    final newIndex = currentIndex + delta;
    if (newIndex >= 0 && newIndex < currentProject.pcbImages.length) {
      onIndexChanged(newIndex);
    }
  }

  /// Update image modification
  void updateImageModification(
    ImageModification mod,
    int currentIndex,
    Project? currentProject,
    Function(Project) onProjectUpdated,
  ) {
    if (currentProject == null || currentProject.pcbImages.isEmpty) return;

    final imageToUpdate = currentProject.pcbImages[currentIndex];
    final updatedImage = pcbImageViewFromJson({
      ...pcbImageViewToJson(imageToUpdate),
      'modification': imageModificationToJson(mod),
    });

    final newImages = List<PCBImageView>.from(currentProject.pcbImages);
    newImages[currentIndex] = updatedImage;

    final updatedProject = currentProject.copyWith(pcbImages: newImages);
    onProjectUpdated(updatedProject);
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
}
