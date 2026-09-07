from pathlib import Path
import pytest
from chino_inference.model_registry import ModelRegistry
from chino_inference.errors import ModelError


class FakeModel:
    task = 'detect'
    names = {0: 'bird', 1: 'deer'}


def test_registry_loads_detect_model_and_normalizes_names(tmp_path: Path):
    model_path = tmp_path / 'best.pt'; model_path.write_bytes(b'fake')
    registry = ModelRegistry(model_factory=lambda _: FakeModel())
    metadata = registry.load(str(model_path), device='cpu')
    assert metadata.names == {0: 'bird', 1: 'deer'}
    assert metadata.task == 'detect'
    assert registry.active_model is not None


def test_registry_rejects_non_detection_model(tmp_path: Path):
    model_path = tmp_path / 'seg.pt'; model_path.write_bytes(b'fake')
    model = FakeModel(); model.task = 'segment'
    registry = ModelRegistry(model_factory=lambda _: model)
    with pytest.raises(ModelError) as exc:
        registry.load(str(model_path), device='cpu')
    assert exc.value.code == 'unsupported_model_task'
