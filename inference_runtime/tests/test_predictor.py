from pathlib import Path
from chino_inference.predictor import predict


class FakeScalar:
    def __init__(self, value): self.value = value
    def item(self): return self.value

class FakeXYXY:
    def __init__(self, values): self.values = values
    def tolist(self): return [self.values]

class FakeBox:
    def __init__(self, cls_id, conf, xyxy):
        self.cls = FakeScalar(cls_id); self.conf = FakeScalar(conf); self.xyxy = FakeXYXY(xyxy)

class FakeResult:
    def __init__(self):
        self.orig_shape = (480, 640); self.boxes = [FakeBox(0, 0.91, [100, 120, 420, 500])]

class FakeModel:
    names = {0: 'bird'}
    def __call__(self, image_path, **kwargs): return [FakeResult()]


def test_predict_normalizes_ultralytics_result(tmp_path: Path):
    image = tmp_path / 'a.jpg'; image.write_bytes(b'fake')
    result = predict(FakeModel(), str(image), confidence=0.25, iou=0.7, device='cpu')
    assert result.image_width == 640 and result.image_height == 480
    detection = result.detections[0]
    assert detection.class_id == 0 and detection.class_name == 'bird' and detection.confidence == 0.91
    assert (detection.x1, detection.y1, detection.x2, detection.y2) == (100.0, 120.0, 420.0, 500.0)
