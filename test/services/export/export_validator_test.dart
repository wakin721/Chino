import 'package:chino/domain/category/category.dart';
import 'package:chino/domain/project/chino_project.dart';
import 'package:chino/services/export/export_options.dart';
import 'package:chino/services/export/export_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects non-contiguous YOLO class indices', () {
    final project = ChinoProject(id: 'p', name: 'p', images: const [], annotations: const [], categories: const [Category(id: 'a', yoloIndex: 0, name: 'bird'), Category(id: 'b', yoloIndex: 2, name: 'deer')]);
    final result = validateExport(project, const ExportOptions(destinationPath: 'out')); expect(result.errors, isNotEmpty);
  });
}
