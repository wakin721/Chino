import json
import sys

from .errors import ChinoInferenceError
from .model_registry import ModelRegistry
from .predictor import predict
from .protocol import parse_request, success_response, error_response


def write(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + '\n')
    sys.stdout.flush()


def main() -> int:
    registry = ModelRegistry()
    for line in sys.stdin:
        if not line.strip():
            continue
        request_id = ''
        try:
            raw = json.loads(line)
            if isinstance(raw, dict):
                request_id = raw.get('request_id', '')
            request = parse_request(raw)
            if request.action == 'ping':
                write(success_response(request.request_id, 'ping', service='chino-inference'))
            elif request.action == 'shutdown':
                write(success_response(request.request_id, 'shutdown'))
                return 0
            elif request.action == 'load_model':
                metadata = registry.load(request.payload['model_path'], request.payload.get('device', 'auto'))
                write(success_response(request.request_id, 'load_model', model_id=metadata.model_id, model_path=metadata.path, names=metadata.names, task=metadata.task, device=metadata.device))
            elif request.action == 'predict':
                if registry.active_model is None or registry.metadata is None:
                    raise ChinoInferenceError('model_not_loaded', 'Load a model before prediction.')
                result = predict(registry.active_model, request.payload['image_path'], float(request.payload.get('confidence', 0.25)), float(request.payload.get('iou', 0.7)), registry.metadata.device)
                write(success_response(request.request_id, 'predict', image_width=result.image_width, image_height=result.image_height, detections=[d.__dict__ for d in result.detections]))
        except ChinoInferenceError as exc:
            write(error_response(request_id, exc.code, exc.message))
        except Exception as exc:
            write(error_response(request_id, 'internal_error', str(exc)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
