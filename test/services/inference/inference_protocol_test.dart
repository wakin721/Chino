import 'package:chino/services/inference/inference_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes a prediction response without conflating class and category ids', () {
    final response = decodeInferenceResponse({'protocol': 1, 'request_id': 'r1', 'ok': true, 'action': 'predict', 'detections': [{'class_id': 3, 'class_name': 'bird', 'confidence': 0.9, 'x1': 1.0, 'y1': 2.0, 'x2': 20.0, 'y2': 30.0}]});
    expect(response.requestId, 'r1'); expect(response.detections.single.classId, 3); expect(response.detections.single.className, 'bird');
  });
  test('rejects unsupported protocol versions', () { expect(() => decodeInferenceResponse({'protocol': 2, 'request_id': 'x', 'ok': true}), throwsA(isA<InferenceException>())); });
}
