import '../../domain/project/chino_project.dart';

class ImportSummary {
  const ImportSummary({required this.project, this.warnings = const [], this.failedFiles = const []});
  final ChinoProject project;
  final List<String> warnings;
  final List<String> failedFiles;
  int get importedImageCount => project.images.length;
  int get importedAnnotationCount => project.annotations.length;
}
