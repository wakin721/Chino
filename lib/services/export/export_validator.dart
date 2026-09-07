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
  if (actual.length != expected.length || Iterable.generate(expected.length).any((i) => actual[i] != expected[i])) {
    errors.add('YOLO class indices must be contiguous from 0.');
  }
  final categoryIds = project.categories.map((e) => e.id).toSet();
  for (final annotation in project.annotations) {
    if (!categoryIds.contains(annotation.categoryId)) errors.add('Annotation ${annotation.id} references a missing category.');
    if (annotation.box.width <= 0 || annotation.box.height <= 0) errors.add('Annotation ${annotation.id} has an invalid box.');
  }
  if (options.destinationPath.trim().isEmpty) errors.add('Export destination is required.');
  return ExportValidationResult(errors: errors);
}
