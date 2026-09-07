from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Detection:
    class_id: int
    class_name: str
    confidence: float
    x1: float
    y1: float
    x2: float
    y2: float


@dataclass(frozen=True)
class PredictionResult:
    image_width: int
    image_height: int
    detections: list[Detection]


def predict(model: Any, image_path: str, confidence: float, iou: float, device: str) -> PredictionResult:
    if not Path(image_path).is_file():
        raise FileNotFoundError(image_path)
    results = model(image_path, conf=confidence, iou=iou, device=device, verbose=False)
    if not results:
        raise RuntimeError('Model returned no result object.')
    result = results[0]
    image_height, image_width = result.orig_shape
    names = getattr(model, 'names', {})
    detections: list[Detection] = []
    for box in result.boxes:
        class_id = int(box.cls.item())
        confidence_value = float(box.conf.item())
        x1, y1, x2, y2 = [float(v) for v in box.xyxy.tolist()[0]]
        class_name = str(names[class_id] if not isinstance(names, list) else names[class_id])
        detections.append(Detection(class_id, class_name, confidence_value, x1, y1, x2, y2))
    return PredictionResult(int(image_width), int(image_height), detections)
