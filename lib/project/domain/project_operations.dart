import 'package:file_picker/file_picker.dart';
import '../api/application_api.dart';
import '../data/project.dart';

typedef ProjectResult = ({bool success, Project? project, String? error});

ProjectResult createProject(String id, String name) => (
  success: true,
  project: projectFromJson({
    'id': id,
    'name': name,
    'lastUpdated': DateTime.now().toIso8601String(),
    'logicalComponents': <String, dynamic>{},
    'logicalNets': <String, dynamic>{},
    'schematicFilePath': null,
    'pcbImages': <dynamic>[],
  }),
  error: null,
);

Future<ProjectResult> loadProject(ApplicationAPI api) async {
  
  final result = await FilePicker.platform.pickFiles();
  if (result == null) return (success: false, project: null, error: 'Load cancelled.');
  if (result.files.length != 1) {
    return (success: false, project: null, error: 'Please select a single .pcbrev file.');
  }
  final path = result.files.single.path!;
  if (!path.endsWith('.pcbrev')) {
    return (success: false, project: null, error: 'Invalid file type. Please select a .pcbrev file.');
  }
  try {
    final opened = await api.openProject(path);
    return (success: true, project: opened.project, error: null);
  } catch (e) {
    return (success: false, project: null, error: e.toString());
  }
}

Future<ProjectResult> saveProject(
  ApplicationAPI api,
  Project? project,
) async {

  if (project == null) return (success: false, project: null, error: 'No project to save.');

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Please select an output file:',
    fileName: 'project.pcbrev',
  );
  
  if (path == null) return (success: false, project: null, error: 'Save cancelled.');
  if (!path.endsWith('.pcbrev')) {
    return (success: false, project: null, error: 'Invalid file type. Please select a .pcbrev file.');
  }
  try {
    await api.saveProject(project, path);
    return (success: true, project: project, error: null);
  } catch (e) {
    return (success: false, project: null, error: e.toString());
  }
}