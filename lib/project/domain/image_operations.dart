import '../api/application_api.dart';
import '../data/project.dart';
import '../../pcb_viewer/data/image_modification.dart';

typedef ImageResult = ({
  bool success,
  Project? project,
  int? newIndex,
  String? error,
});

Future<ImageResult> addImageToProject({
  required ApplicationAPI api,
  required Project project,
  required List<String> imagePaths,
}) async {
  try {
    var updatedProject = project;
    
    for (final path in imagePaths) {
      final enhancedPath = await api.processImage(path);
      updatedProject = api.addImage(
        project: updatedProject,
        path: enhancedPath,
        layer: 'top',
      );
    }
    
    final newIndex = updatedProject.pcbImages.length - 1;
    return (
      success: true,
      project: updatedProject,
      newIndex: newIndex,
      error: null,
    );
  } catch (e) {
    return (success: false, project: null, newIndex: null, error: e.toString());
  }
}

Project updateImageModification(
  Project project,
  int imageIndex,
  ImageModification modification,
) {
  if (imageIndex < 0 || imageIndex >= project.pcbImages.length) {
    return project;
  }
  
  final image = project.pcbImages[imageIndex];
  final updatedImage = pcbImageViewFromJson({
    ...pcbImageViewToJson(image),
    'modification': imageModificationToJson(modification),
  });
  
  final newImages = List<PCBImageView>.from(project.pcbImages);
  newImages[imageIndex] = updatedImage;
  
  return project.copyWith(pcbImages: newImages);
}