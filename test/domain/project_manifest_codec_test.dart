import 'package:chino/domain/annotation/annotation.dart';
import 'package:chino/domain/annotation/bounding_box.dart';
import 'package:chino/domain/category/category.dart';
import 'package:chino/domain/dataset/dataset_image.dart';
import 'package:chino/domain/project/chino_project.dart';
import 'package:chino/domain/project/project_manifest_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips a version 1 project manifest', () {
    final project = ChinoProject(id: 'p1', name: 'demo', categories: const [Category(id: 'c0', yoloIndex: 0, name: 'bird')], images: const [DatasetImage(id: 'i1', path: 'a.jpg', filename: 'a.jpg', width: 800, height: 600)], annotations: const [Annotation(id: 'a1', imageId: 'i1', categoryId: 'c0', box: BoundingBox(left: 100, top: 100, width: 200, height: 100), source: AnnotationSource.imported)]);
    final encoded = encodeProject(project); expect(encoded['version'], 1); final decoded = decodeProject(encoded); expect(decoded.name, 'demo'); expect(decoded.images.single.width, 800); expect(decoded.annotations.single.box.left, 100);
  });
}
