import 'package:chino/domain/annotation/bounding_box.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts YOLO normalized coordinates to image coordinates', () {
    final box = BoundingBox.fromYolo(xCenter: 0.5, yCenter: 0.5, width: 0.25, height: 0.5, imageWidth: 800, imageHeight: 600);
    expect(box.left, 300); expect(box.top, 150); expect(box.width, 200); expect(box.height, 300);
  });
  test('round trips image coordinates to YOLO coordinates', () {
    const box = BoundingBox(left: 300, top: 150, width: 200, height: 300);
    final yolo = box.toYolo(imageWidth: 800, imageHeight: 600);
    expect(yolo[0], closeTo(0.5, 1e-9)); expect(yolo[1], closeTo(0.5, 1e-9)); expect(yolo[2], closeTo(0.25, 1e-9)); expect(yolo[3], closeTo(0.5, 1e-9));
  });
  test('clamps boxes to image bounds', () {
    const box = BoundingBox(left: -10, top: 20, width: 100, height: 100);
    final clamped = box.clampToImage(imageWidth: 80, imageHeight: 60);
    expect(clamped.left, 0); expect(clamped.top, 20); expect(clamped.width, 80); expect(clamped.height, 40);
  });
}
