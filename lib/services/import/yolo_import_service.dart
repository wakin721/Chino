import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../domain/annotation/annotation.dart';
import '../../domain/annotation/bounding_box.dart';
import '../../domain/category/category.dart';
import '../../domain/dataset/dataset_image.dart';
import '../../domain/project/chino_project.dart';
import '../../features/import/import_summary.dart';
import 'image_probe.dart';
import 'yolo_dataset_discovery.dart';
import 'yolo_label_parser.dart';
import 'yolo_names_parser.dart';

class YoloImportService {
  YoloImportService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final Uuid _uuid;

  Future<ImportSummary> importDirectory(String rootPath) async {
    final layout = await discoverYoloDataset(rootPath);
    final warnings = <String>[];
    final failed = <String>[];
    final names = layout.dataYamlPath == null ? <String>[] : parseYoloNames(await File(layout.dataYamlPath!).readAsString());
    final categories = <Category>[
      for (var i = 0; i < names.length; i++) Category(id: 'class-$i', yoloIndex: i, name: names[i]),
    ];
    final images = <DatasetImage>[];
    final annotations = <Annotation>[];

    for (final discovered in layout.imageEntries) {
      try {
        final size = await probeImage(discovered.imagePath);
        final imageId = _uuid.v4();
        images.add(DatasetImage(
          id: imageId,
          path: p.absolute(discovered.imagePath),
          filename: p.basename(discovered.imagePath),
          width: size.width,
          height: size.height,
          split: discovered.split,
        ));
        final labelPath = discovered.labelPath;
        if (labelPath == null) continue;
        final lines = await File(labelPath).readAsLines();
        for (var lineNumber = 0; lineNumber < lines.length; lineNumber++) {
          final line = lines[lineNumber].trim();
          if (line.isEmpty) continue;
          try {
            final row = parseYoloLabelRow(line);
            while (categories.length <= row.classId) {
              final index = categories.length;
              categories.add(Category(id: 'class-$index', yoloIndex: index, name: 'class_$index'));
            }
            if (row.width <= 0 || row.height <= 0) throw const FormatException('Box width and height must be positive.');
            final box = BoundingBox.fromYolo(
              xCenter: row.xCenter,
              yCenter: row.yCenter,
              width: row.width,
              height: row.height,
              imageWidth: size.width,
              imageHeight: size.height,
            ).clampToImage(imageWidth: size.width, imageHeight: size.height);
            if (box.width <= 0 || box.height <= 0) throw const FormatException('Box lies outside the image.');
            annotations.add(Annotation(
              id: _uuid.v4(),
              imageId: imageId,
              categoryId: categories[row.classId].id,
              box: box,
              source: AnnotationSource.imported,
            ));
          } on FormatException catch (error) {
            warnings.add('$labelPath:${lineNumber + 1}: ${error.message}');
          }
        }
      } catch (error) {
        failed.add('${discovered.imagePath}: $error');
      }
    }

    return ImportSummary(
      project: ChinoProject(
        id: _uuid.v4(),
        name: p.basename(p.normalize(rootPath)),
        images: List.unmodifiable(images),
        categories: List.unmodifiable(categories),
        annotations: List.unmodifiable(annotations),
      ),
      warnings: List.unmodifiable(warnings),
      failedFiles: List.unmodifiable(failed),
    );
  }
}
