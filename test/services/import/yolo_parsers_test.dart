import 'package:chino/services/import/yolo_label_parser.dart';
import 'package:chino/services/import/yolo_names_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a five-field YOLO detection row', () { final row = parseYoloLabelRow('2 0.5 0.4 0.2 0.1'); expect(row.classId, 2); expect(row.xCenter, 0.5); });
  test('rejects malformed detection rows', () { expect(() => parseYoloLabelRow('-1 0.5 0.4 0.2 0.1'), throwsFormatException); expect(() => parseYoloLabelRow('0 0.5 0.4'), throwsFormatException); });
  test('parses class names from list or map', () { expect(parseYoloNames('names: [bird, deer]'), ['bird', 'deer']); expect(parseYoloNames('names:\n  1: deer\n  0: bird\n'), ['bird', 'deer']); });
}
