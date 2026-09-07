from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Any
import uuid

from .errors import ModelError
from .device import resolve_device


@dataclass(frozen=True)
class ModelMetadata:
    model_id: str
    path: str
    names: dict[int, str]
    task: str
    device: str


class ModelRegistry:
    def __init__(self, model_factory: Callable[[str], Any] | None = None):
        self._model_factory = model_factory
        self.active_model: Any | None = None
        self.metadata: ModelMetadata | None = None

    def _factory(self, path: str):
        if self._model_factory is not None:
            return self._model_factory(path)
        from ultralytics import YOLO
        return YOLO(path)

    def load(self, path: str, device: str = 'auto') -> ModelMetadata:
        model_path = Path(path)
        if not model_path.is_file():
            raise ModelError('model_not_found', f'Model file not found: {path}')
        model = self._factory(str(model_path))
        task = getattr(model, 'task', None)
        if task != 'detect':
            raise ModelError('unsupported_model_task', f'Only detection models are supported; got {task!r}.')
        raw_names = getattr(model, 'names', {})
        if isinstance(raw_names, list):
            names = {i: str(name) for i, name in enumerate(raw_names)}
        else:
            names = {int(k): str(v) for k, v in dict(raw_names).items()}
        selected_device = resolve_device(device)
        metadata = ModelMetadata(str(uuid.uuid4()), str(model_path), names, task, selected_device)
        self.active_model = model
        self.metadata = metadata
        return metadata
