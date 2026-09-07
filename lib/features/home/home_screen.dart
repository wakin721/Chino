import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/import/yolo_import_service.dart';
import '../../services/project/project_store.dart';
import '../annotation_workspace/annotation_workspace_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _openWorkspace(Future<dynamic> Function() loader) async {
    setState(() { _busy = true; _message = null; });
    try {
      final project = await loader();
      if (project == null || !mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnnotationWorkspaceScreen(initialProject: project)));
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importDataset() async {
    final directory = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select an image folder or YOLO dataset');
    if (directory == null) return;
    await _openWorkspace(() async {
      final summary = await YoloImportService().importDirectory(directory);
      if (summary.warnings.isNotEmpty || summary.failedFiles.isNotEmpty) {
        setState(() => _message = 'Imported ${summary.importedImageCount} images / ${summary.importedAnnotationCount} boxes. ${summary.warnings.length} warnings, ${summary.failedFiles.length} failed files.');
      }
      return summary.project;
    });
  }

  Future<void> _openProject() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    final path = result?.files.single.path;
    if (path == null) return;
    await _openWorkspace(() => ProjectStore().load(path));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chino')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dataset_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text('Chino', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('Material 3 desktop annotation for YOLO datasets and direct .pt-assisted detection.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    if (_busy) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator()),
                    FilledButton.icon(onPressed: _busy ? null : _importDataset, icon: const Icon(Icons.folder_open), label: const Text('Import dataset')),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: _busy ? null : _openProject, icon: const Icon(Icons.description_outlined), label: const Text('Open project')),
                    if (_message != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
