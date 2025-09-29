import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/project.dart';
import '../api/application_api.dart';

/// Manages project-related operations like opening, saving, and initializing projects
class ProjectManager {
  final ApplicationAPI _applicationAPI;

  ProjectManager(this._applicationAPI);

  /// Initialize a new project with default values
  Project createInitialProject() {
    return projectFromJson({
      'id': '1',
      'name': 'New Project',
      'lastUpdated': DateTime.now().toIso8601String(),
      'logicalComponents': <String, dynamic>{},
      'logicalNets': <String, dynamic>{},
      'schematicFilePath': null,
      'pcbImages': <dynamic>[],
    });
  }

  /// Save project to file
  Future<void> saveProject(
    Project? currentProject,
    BuildContext context,
    VoidCallback onSuccess,
    VoidCallback onError,
  ) async {
    if (currentProject == null) return;

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'project.pcbrev',
    );

    if (outputFile != null) {
      try {
        await _applicationAPI.saveProject(currentProject, outputFile);
        onSuccess();
      } catch (e) {
        onError();
      }
    }
  }

  /// Open project from file
  Future<Project?> openProject(
    BuildContext context,
    Function(Project) onSuccess,
    VoidCallback onError,
  ) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final path = result.files.single.path!;
      if (!path.endsWith('.pcbrev')) {
        _showErrorSnackBar(context, 'Invalid file type. Please select a .pcbrev file.');
        return null;
      }

      try {
        final openedProject = await _applicationAPI.openProject(path);
        onSuccess(openedProject.project);
        return openedProject.project;
      } catch (e) {
        _showErrorSnackBar(context, 'Error opening project: $e');
        onError();
      }
    }
    return null;
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
