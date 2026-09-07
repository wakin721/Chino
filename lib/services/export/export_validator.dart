import '../../domain/project/chino_project.dart';
import 'export_options.dart';

class ExportValidationResult {
  const ExportValidationResult({this.errors = const [], this.warnings = const []});
  final List<String> errors;
  final List<String> warnings;
  bool get isValid => errors.isEmpty;
}

ExportValidationResult validateExport(ChinoProject project, ExportOptions options) {
  final errors = <String>[];
  final expected = List<int>.generate(project.categories.length, (i) => i);
  final actual = project.categories.map((e) => e.yoloIndex).toList()..sort();
  if (actual.length != expected.length) {
    errors.add('YOLO class indices must be contiguous from 0.');
  } else {
    for (var i = 0; i < expected.length; i++) {
      if (actual[i] != expected[i]) {
        errors.add('YOLO class indices must be contiguous from 0.');
        break;
      }
    }
  }
  final categoryIds = project.categories.map((e) => e.id).toSet();
  final imagesById = {for (final image in project.images) image.id: image};
  for (final annotation in project.annotations) {
    if (!categoryIds.contains(annotation.categoryId)) errors.add('Annotation ${annotation.id} references a missing category.');
    final image = imagesById[annotation.imageId];
    if (image == null) {
      errors.add('Annotation ${annotation.id} references a missing image.');
      continue;
    }
    final box = annotation.box;
    if (box.width <= 0 || box.height <= 0 || box.left < 0 || box.top < 0 || box.right > image.width || box.bottom > image.height) {
      errors.add('Annotation ${annotation.id} has an invalid box.');
    }
  }
  if (options.destinationPath.trim().isEmpty) errors.add('Export destination is required.');
  return ExportValidationResult(errors: errors);
}
