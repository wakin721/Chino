import 'package:chino/domain/dataset/dataset_image.dart';
import 'package:chino/domain/inference/class_mapping.dart';
import 'package:chino/features/annotation_workspace/prediction_importer.dart';
import 'package:chino/services/inference/inference_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts mapped predictions into editable image-space annotations', () {
    const image = DatasetImage(id: 'i', path: 'x.jpg', filename: 'x.jpg', width: 640, height: 480);
    const detection = InferenceDetection(classId: 0, className: 'bird', confidence: 0.91, x1: 100, y1: 120, x2: 420, y2: 500);
    final annotations = annotationsFromPredictions(image: image, detections: const [detection], mapping: const ClassMapping({0: 'bird-id'}), modelId: 'm');
    expect(annotations.single.categoryId, 'bird-id');
    expect(annotations.single.box.left, 100);
    expect(annotations.single.box.width, 320);
    expect(annotations.single.box.bottom, 480);
  });
}
