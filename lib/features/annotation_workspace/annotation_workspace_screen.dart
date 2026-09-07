import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../domain/annotation/annotation.dart';
import '../../domain/annotation/bounding_box.dart';
import '../../domain/category/category.dart';
import '../../domain/commands/undo_redo_stack.dart';
import '../../domain/inference/class_mapping.dart';
import '../../domain/project/chino_project.dart';
import '../../services/export/export_options.dart';
import '../../services/export/yolo_export_service.dart';
import '../../services/inference/inference_service.dart';
import '../../services/inference/inference_worker.dart';
import '../../services/project/project_store.dart';
import 'annotation_canvas.dart';
import 'prediction_importer.dart';

class AnnotationWorkspaceScreen extends StatefulWidget {
  const AnnotationWorkspaceScreen({super.key, required this.initialProject});
  final ChinoProject initialProject;

  @override
  State<AnnotationWorkspaceScreen> createState() => _AnnotationWorkspaceScreenState();
}

class _AnnotationWorkspaceScreenState extends State<AnnotationWorkspaceScreen> {
  late ChinoProject _project;
  final _history = UndoRedoStack();
  var _imageIndex = 0;
  String? _selectedId;
  InferenceWorker? _worker;
  InferenceService? _inference;
  InferenceModelMetadata? _model;
  ClassMapping? _mapping;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _project = widget.initialProject;
    if (_project.categories.isEmpty) {
      _project = _project.copyWith(categories: const [Category(id: 'class-0', yoloIndex: 0, name: 'object')]);
    }
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  void _edit(ProjectEdit edit) => setState(() => _project = _history.execute(_project, edit));

  void _create(BoundingBox box) {
    if (_project.images.isEmpty) return;
    final image = _project.images[_imageIndex];
    final annotation = Annotation(id: const Uuid().v4(), imageId: image.id, categoryId: _project.categories.first.id, box: box, source: AnnotationSource.manual);
    _edit((project) => project.copyWith(annotations: [...project.annotations, annotation]));
    setState(() => _selectedId = annotation.id);
  }

  void _update(String id, BoundingBox box) => _edit((project) => project.copyWith(annotations: [for (final a in project.annotations) if (a.id == id) a.copyWith(box: box) else a]));

  void _deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    _edit((project) => project.copyWith(annotations: project.annotations.where((a) => a.id != id).toList()));
    setState(() => _selectedId = null);
  }

  void _reassign(String categoryId) {
    final id = _selectedId;
    if (id == null) return;
    _edit((project) => project.copyWith(annotations: [for (final a in project.annotations) if (a.id == id) a.copyWith(categoryId: categoryId) else a]));
  }

  Future<void> _save() async {
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Save Chino project', fileName: '${_project.name}.chino.json', allowedExtensions: ['json'], type: FileType.custom);
    if (path != null) await ProjectStore().save(_project, path);
  }

  Future<void> _export() async {
    final root = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose YOLO export parent folder');
    if (root == null) return;
    final destination = p.join(root, '${_project.name}_yolo');
    try {
      await const YoloExportService().export(_project, ExportOptions(destinationPath: destination));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $destination')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _loadModel() async {
    final trusted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Open a trusted .pt model only'),
      content: const Text('PyTorch .pt files can contain serialized executable content. Chino runs the selected model locally; only load files from sources you trust.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))],
    ));
    if (trusted != true) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pt']);
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      _worker ??= await InferenceWorker.start(Platform.isWindows ? 'python' : 'python3', ['-m', 'chino_inference'], workingDirectory: p.join(Directory.current.path, 'inference_runtime'));
      _inference ??= InferenceService(_worker!);
      final metadata = await _inference!.loadModel(path);
      var mapping = ClassMapping.byExactName(metadata.names, _project.categories);
      final missing = metadata.names.entries.where((e) => mapping.categoryIdFor(e.key) == null).toList();
      if (missing.isNotEmpty && mounted) {
        final add = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
          title: const Text('Model classes differ from project'),
          content: Text('Unmapped classes: ${missing.map((e) => e.value).join(', ')}. Add them to this project?'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep unmapped')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add classes'))],
        ));
        if (add == true) {
          final categories = [..._project.categories];
          for (final entry in missing) {
            if (categories.any((c) => c.name == entry.value)) continue;
            categories.add(Category(id: const Uuid().v4(), yoloIndex: categories.length, name: entry.value));
          }
          _edit((project) => project.copyWith(categories: categories));
          mapping = ClassMapping.byExactName(metadata.names, _project.categories);
        }
      }
      setState(() { _model = metadata; _mapping = mapping; });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Model load failed: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inferCurrent() async {
    if (_project.images.isEmpty || _inference == null || _model == null || _mapping == null) return;
    final image = _project.images[_imageIndex];
    setState(() => _busy = true);
    try {
      final response = await _inference!.predict(image.path);
      final predictions = annotationsFromPredictions(image: image, detections: response.detections, mapping: _mapping!, modelId: _model!.modelId);
      _edit((project) => project.copyWith(annotations: [...project.annotations, ...predictions]));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inference failed: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_project.images.isEmpty) return Scaffold(appBar: AppBar(title: Text(_project.name)), body: const Center(child: Text('No supported images were imported.')));
    final image = _project.images[_imageIndex];
    final annotations = _project.annotations.where((a) => a.imageId == image.id).toList();
    final categoryNames = {for (final c in _project.categories) c.id: c.name};
    final selected = _selectedId == null ? null : _project.annotations.cast<Annotation?>().firstWhere((a) => a?.id == _selectedId, orElse: () => null);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () => setState(() => _project = _history.undo(_project)),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () => setState(() => _project = _history.redo(_project)),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text('${_project.name} — ${image.filename}'),
            actions: [
              IconButton(onPressed: _history.canUndo ? () => setState(() => _project = _history.undo(_project)) : null, tooltip: 'Undo', icon: const Icon(Icons.undo)),
              IconButton(onPressed: _history.canRedo ? () => setState(() => _project = _history.redo(_project)) : null, tooltip: 'Redo', icon: const Icon(Icons.redo)),
              IconButton(onPressed: _busy ? null : _loadModel, tooltip: 'Load .pt model', icon: const Icon(Icons.model_training)),
              FilledButton.tonalIcon(onPressed: _busy || _model == null ? null : _inferCurrent, icon: const Icon(Icons.auto_awesome), label: const Text('Detect')),
              IconButton(onPressed: _save, tooltip: 'Save project', icon: const Icon(Icons.save_outlined)),
              IconButton(onPressed: _export, tooltip: 'Export YOLO dataset', icon: const Icon(Icons.file_upload_outlined)),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              SizedBox(
                width: 230,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: ListView.builder(
                    itemCount: _project.images.length,
                    itemBuilder: (context, index) {
                      final item = _project.images[index];
                      final count = _project.annotations.where((a) => a.imageId == item.id).length;
                      return ListTile(
                        selected: index == _imageIndex,
                        leading: const Icon(Icons.image_outlined),
                        title: Text(item.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${item.split.name} · $count boxes'),
                        onTap: () => setState(() { _imageIndex = index; _selectedId = null; }),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: Colors.black87,
                  child: AnnotationCanvas(
                    image: image,
                    annotations: annotations,
                    categoryNames: categoryNames,
                    selectedId: _selectedId,
                    onSelect: (id) => setState(() => _selectedId = id),
                    onCreate: _create,
                    onUpdate: _update,
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Column(
                    children: [
                      if (selected != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Expanded(child: DropdownButtonFormField<String>(value: selected.categoryId, decoration: const InputDecoration(labelText: 'Class'), items: [for (final c in _project.categories) DropdownMenuItem(value: c.id, child: Text(c.name))], onChanged: (value) { if (value != null) _reassign(value); })),
                            IconButton(onPressed: _deleteSelected, tooltip: 'Delete box', icon: const Icon(Icons.delete_outline)),
                          ]),
                        ),
                      if (_busy) const LinearProgressIndicator(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: annotations.length,
                          itemBuilder: (context, index) {
                            final a = annotations[index];
                            return ListTile(
                              selected: a.id == _selectedId,
                              title: Text(categoryNames[a.categoryId] ?? a.categoryId),
                              subtitle: Text(a.confidence == null ? a.source.name : '${a.source.name} · ${(a.confidence! * 100).toStringAsFixed(1)}%'),
                              onTap: () => setState(() => _selectedId = a.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
