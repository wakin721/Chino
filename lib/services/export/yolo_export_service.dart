import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../domain/dataset/dataset_split.dart';
import '../../domain/project/chino_project.dart';
import 'export_options.dart';
import 'export_validator.dart';

class ExportResult {
  const ExportResult(this.destinationPath, this.imageCount, this.annotationCount);
  final String destinationPath;
  final int imageCount;
  final int annotationCount;
}

class YoloExportService {
  const YoloExportService();

  Future<ExportResult> export(ChinoProject project, ExportOptions options) async {
    final validation = validateExport(project, options);
    if (!validation.isValid) throw StateError(validation.errors.join('\n'));
    final destination = Directory(options.destinationPath);
    if (await destination.exists() && !options.overwriteExisting) {
      throw FileSystemException('Destination already exists', destination.path);
    }
    final staging = Directory('${destination.path}.chino-staging-${const Uuid().v4()}');
    final backup = Directory('${destination.path}.chino-backup');
    await staging.create(recursive: true);
    try {
      for (final image in project.images) {
        final split = switch (image.split) {
          DatasetSplit.train => 'train',
          DatasetSplit.val => 'val',
          DatasetSplit.test => 'test',
          DatasetSplit.unassigned => switch (options.unassignedPolicy) {
              UnassignedPolicy.train => 'train',
              UnassignedPolicy.flat => '',
              UnassignedPolicy.reject => throw StateError('Unassigned image: ${image.filename}'),
            },
        };
        final imageDir = Directory(split.isEmpty ? p.join(staging.path, 'images') : p.join(staging.path, 'images', split));
        final labelDir = Directory(split.isEmpty ? p.join(staging.path, 'labels') : p.join(staging.path, 'labels', split));
        await imageDir.create(recursive: true);
        await labelDir.create(recursive: true);
        var outputName = image.filename;
        var outputImage = File(p.join(imageDir.path, outputName));
        if (await outputImage.exists()) {
          outputName = '${image.id}_${image.filename}';
          outputImage = File(p.join(imageDir.path, outputName));
        }
        await File(image.path).copy(outputImage.path);
        final label = File(p.join(labelDir.path, '${p.basenameWithoutExtension(outputName)}.txt'));
        final rows = <String>[];
        for (final annotation in project.annotations.where((a) => a.imageId == image.id)) {
          final category = project.categories.singleWhere((c) => c.id == annotation.categoryId);
          final yolo = annotation.box.toYolo(imageWidth: image.width, imageHeight: image.height);
          rows.add('${category.yoloIndex} ${yolo.map((v) => v.toStringAsFixed(8)).join(' ')}');
        }
        await label.writeAsString(rows.isEmpty ? '' : '${rows.join('\n')}\n');
      }
      await File(p.join(staging.path, 'data.yaml')).writeAsString(_dataYaml(project, options));

      if (await backup.exists()) await backup.delete(recursive: true);
      if (await destination.exists()) await destination.rename(backup.path);
      try {
        await staging.rename(destination.path);
        if (await backup.exists()) await backup.delete(recursive: true);
      } catch (_) {
        if (!await destination.exists() && await backup.exists()) await backup.rename(destination.path);
        rethrow;
      }
      return ExportResult(destination.path, project.images.length, project.annotations.length);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  String _dataYaml(ChinoProject project, ExportOptions options) {
    final used = project.images.map((e) => e.split).toSet();
    final lines = <String>['path: .'];
    if (options.unassignedPolicy == UnassignedPolicy.flat && used.every((s) => s == DatasetSplit.unassigned)) {
      lines.add('train: images');
    } else {
      if (used.contains(DatasetSplit.train) || (used.contains(DatasetSplit.unassigned) && options.unassignedPolicy == UnassignedPolicy.train)) lines.add('train: images/train');
      if (used.contains(DatasetSplit.val)) lines.add('val: images/val');
      if (used.contains(DatasetSplit.test)) lines.add('test: images/test');
    }
    lines.add('names:');
    final categories = [...project.categories]..sort((a, b) => a.yoloIndex.compareTo(b.yoloIndex));
    for (final category in categories) {
      lines.add('  ${category.yoloIndex}: ${jsonEncode(category.name)}');
    }
    return '${lines.join('\n')}\n';
  }
}
