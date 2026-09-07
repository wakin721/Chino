import 'package:uuid/uuid.dart';
import '../../domain/annotation/annotation.dart';
import '../../domain/annotation/bounding_box.dart';
import '../../domain/dataset/dataset_image.dart';
import '../../domain/inference/class_mapping.dart';
import '../../services/inference/inference_protocol.dart';

List<Annotation> annotationsFromPredictions({
  required DatasetImage image,
  required List<InferenceDetection> detections,
  required ClassMapping mapping,
  required String modelId,
}) {
  const uuid = Uuid();
  final result = <Annotation>[];
  for (final detection in detections) {
    final categoryId = mapping.categoryIdFor(detection.classId);
    if (categoryId == null) continue;
    final box = BoundingBox(
      left: detection.x1,
      top: detection.y1,
      width: detection.x2 - detection.x1,
      height: detection.y2 - detection.y1,
    ).clampToImage(imageWidth: image.width, imageHeight: image.height);
    if (box.width <= 0 || box.height <= 0) continue;
    result.add(Annotation(
      id: uuid.v4(),
      imageId: image.id,
      categoryId: categoryId,
      box: box,
      source: AnnotationSource.prediction,
      confidence: detection.confidence,
      modelId: modelId,
    ));
  }
  return result;
}
