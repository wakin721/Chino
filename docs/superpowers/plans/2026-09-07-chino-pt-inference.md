# Chino `.pt` Inference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a self-contained local inference worker that loads compatible Ultralytics `.pt` detection models, exposes a versioned stdin/stdout JSON protocol, and converts predictions into editable Chino annotations.

**Architecture:** Flutter launches one supervised worker process and communicates by newline-delimited JSON. The worker owns PyTorch/Ultralytics model objects; Flutter owns project state. Model metadata and predictions cross the process boundary as explicit protocol messages so a future non-Python backend can replace the worker without changing the annotation editor.

**Tech Stack:** Python 3.12 runtime bundle, Ultralytics, PyTorch, pytest, Flutter/Dart `Process`, Riverpod, JSONL protocol.

**Spec:** `docs/superpowers/specs/2026-09-07-chino-design.md`

## Global Constraints

- Users load Ultralytics-compatible object-detection `.pt` models directly.
- Packaged releases must not require users to install Python separately.
- The worker listens on no network port by default.
- Protocol messages include `protocol` and `request_id`.
- Predictions include class id/name, confidence, and image-space xyxy geometry.
- Model class indices are never silently equated with unrelated project class ids.
- Default device selection is `auto`, with CPU fallback and CUDA only when available.
- Untrusted `.pt` files must be treated as a security risk and the UI must warn accordingly.

## Planned File Structure

```text
inference_runtime/
  pyproject.toml
  chino_inference/
    __init__.py
    __main__.py
    protocol.py
    model_registry.py
    predictor.py
    device.py
    errors.py
  tests/
    test_protocol.py
    test_model_registry.py
    test_predictor.py

lib/domain/inference/
  inference_model.dart
  inference_detection.dart
  class_mapping.dart
lib/services/inference/
  inference_protocol.dart
  inference_worker.dart
  inference_service.dart
lib/features/model_manager/
  model_manager_controller.dart
  model_manager_dialog.dart
lib/features/annotation_workspace/
  prediction_importer.dart

test/services/inference/...
test/features/model_manager/...
```

---

### Task 1: Define and test protocol schema in Python

**Files:**
- Create: `inference_runtime/pyproject.toml`
- Create: `inference_runtime/chino_inference/protocol.py`
- Create: `inference_runtime/chino_inference/errors.py`
- Test: `inference_runtime/tests/test_protocol.py`

**Interfaces:**
- Produces Python request parser for actions `ping`, `load_model`, `predict`, `shutdown`.
- Produces success/error JSON dictionaries with `protocol: 1`, `request_id`, `ok`.

- [ ] **Step 1: Write failing pytest cases**

```python
def test_parse_predict_request_requires_request_id():
    with pytest.raises(ProtocolError):
        parse_request({'protocol': 1, 'action': 'predict', 'image_path': 'a.jpg'})


def test_error_response_is_machine_readable():
    payload = error_response('abc', 'invalid_request', 'bad request')
    assert payload == {
        'protocol': 1,
        'request_id': 'abc',
        'ok': False,
        'error': {'code': 'invalid_request', 'message': 'bad request'},
    }
```

- [ ] **Step 2: Run and verify failure**

```bash
cd inference_runtime
python -m pytest tests/test_protocol.py -q
```

- [ ] **Step 3: Implement protocol dataclasses/parsers**

Reject unsupported protocol versions with code `unsupported_protocol`; reject unknown actions with `invalid_action`; preserve request id in every response.

- [ ] **Step 4: Verify tests**

```bash
python -m pytest tests/test_protocol.py -q
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add inference_runtime
git commit -m "feat: define Chino inference protocol"
```

---

### Task 2: Implement device detection and model registry

**Files:**
- Create: `inference_runtime/chino_inference/device.py`
- Create: `inference_runtime/chino_inference/model_registry.py`
- Test: `inference_runtime/tests/test_model_registry.py`

**Interfaces:**
- Produces `resolve_device('auto'|'cpu'|'cuda') -> str`.
- Produces `ModelRegistry.load(path) -> ModelMetadata` and cached active model.
- `ModelMetadata` contains `model_id`, `path`, `names: dict[int,str]`, `task`, `device`.

- [ ] **Step 1: Write failing tests with a fake Ultralytics loader**

Verify `auto` selects CUDA only when mocked `torch.cuda.is_available()` is true; verify a non-detect task is rejected with structured code `unsupported_model_task`; verify names are normalized to integer-keyed mapping.

- [ ] **Step 2: Run failing tests**

```bash
python -m pytest tests/test_model_registry.py -q
```

- [ ] **Step 3: Implement registry around injected model factory**

Production factory imports `YOLO` lazily and calls `YOLO(path)`. Do not add unsafe pickle fallback or arbitrary `torch.load` fallback. Reject missing files before invoking Ultralytics.

- [ ] **Step 4: Verify tests**

```bash
python -m pytest tests/test_model_registry.py -q
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add inference_runtime/chino_inference inference_runtime/tests
git commit -m "feat: load compatible pt detection models"
```

---

### Task 3: Implement prediction normalization

**Files:**
- Create: `inference_runtime/chino_inference/predictor.py`
- Test: `inference_runtime/tests/test_predictor.py`

**Interfaces:**
- Produces `predict(model, image_path, confidence, iou, device) -> PredictionResult`.
- Result contains image width/height and detection records with `class_id`, `class_name`, `confidence`, `x1`, `y1`, `x2`, `y2`.

- [ ] **Step 1: Write failing fake-result test**

Mock an Ultralytics result with two boxes and assert conversion to ordinary Python floats/ints and class names.

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_predictor.py -q
```

- [ ] **Step 3: Implement predictor**

Call the loaded model with explicit `conf`, `iou`, `device`, `verbose=False`. Do not return tensors or numpy scalars across the protocol boundary. Validate image path before prediction.

- [ ] **Step 4: Verify tests**

```bash
python -m pytest tests/test_predictor.py -q
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add inference_runtime
git commit -m "feat: normalize YOLO prediction results"
```

---

### Task 4: Build the JSONL worker executable loop

**Files:**
- Create: `inference_runtime/chino_inference/__main__.py`
- Modify: protocol/registry/predictor as needed
- Test: `inference_runtime/tests/test_worker_process.py`

**Interfaces:**
- stdin: one UTF-8 JSON object per line.
- stdout: exactly one response JSON line per request; diagnostic logs go to stderr.

- [ ] **Step 1: Write subprocess smoke test**

Start `python -m chino_inference`, send `ping`, assert response `{protocol:1, request_id:'1', ok:true, ...}`, then send shutdown and assert clean exit.

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_worker_process.py -q
```

- [ ] **Step 3: Implement loop with stdout discipline**

Never print logs to stdout. Catch per-request exceptions and return structured errors without killing the worker unless stdin closes or shutdown is requested.

- [ ] **Step 4: Verify entire Python suite**

```bash
python -m pytest -q
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add inference_runtime
git commit -m "feat: run local inference worker over JSONL"
```

---

### Task 5: Implement Flutter protocol/domain types

**Files:**
- Create: `lib/domain/inference/inference_model.dart`
- Create: `lib/domain/inference/inference_detection.dart`
- Create: `lib/services/inference/inference_protocol.dart`
- Test: `test/services/inference/inference_protocol_test.dart`

**Interfaces:**
- Produces typed request encoder and response decoder matching protocol version 1.

- [ ] **Step 1: Write failing JSON decode tests**

Decode a model-loaded response and a prediction response; reject `protocol:2`; decode structured errors into `InferenceException(code,message)`.

- [ ] **Step 2: Verify failure**

```bash
flutter test test/services/inference/inference_protocol_test.dart
```

- [ ] **Step 3: Implement immutable Dart protocol models**

Keep external `classId` separate from Chino `categoryId`.

- [ ] **Step 4: Verify tests**

```bash
flutter test test/services/inference/inference_protocol_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/inference lib/services/inference test/services/inference
git commit -m "feat: add Flutter inference protocol models"
```

---

### Task 6: Supervise the local worker from Flutter

**Files:**
- Create: `lib/services/inference/inference_worker.dart`
- Create: `lib/services/inference/inference_service.dart`
- Test: `test/services/inference/inference_worker_test.dart`

**Interfaces:**
- Produces `InferenceWorker.start(executablePath,args)`, `request`, `dispose`.
- Produces `InferenceService.loadModel`, `predict`, `availableDevices`, `shutdown`.

- [ ] **Step 1: Write failing worker tests using a tiny fake Dart/Python echo process fixture**

Verify concurrent request ids are matched to correct completers, malformed stdout terminates the affected worker with protocol error, stderr does not corrupt responses, and disposal completes pending requests with cancellation errors.

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/services/inference/inference_worker_test.dart
```

- [ ] **Step 3: Implement process supervision**

Generate UUID request ids. Maintain `Map<String, Completer<InferenceResponse>>`. Read stdout by lines and decode JSON; read stderr separately into diagnostics. If worker exits unexpectedly, fail all pending requests and expose an exited state.

- [ ] **Step 4: Verify tests**

```bash
flutter test test/services/inference/inference_worker_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/inference test/services/inference
git commit -m "feat: supervise local inference worker"
```

---

### Task 7: Add model manager and explicit model-to-project class mapping

**Files:**
- Create: `lib/domain/inference/class_mapping.dart`
- Create: `lib/features/model_manager/model_manager_controller.dart`
- Create: `lib/features/model_manager/model_manager_dialog.dart`
- Test: `test/features/model_manager/model_manager_controller_test.dart`

**Interfaces:**
- Produces `ClassMapping` from model class id to Chino stable category id.
- Model manager supports choose `.pt`, load, map matching names automatically, flag unresolved names, append categories only after explicit user action.

- [ ] **Step 1: Write failing mapping tests**

Project `bird,deer`; model `0:bird,1:fox`. Assert bird auto-maps by exact name and fox remains unresolved; integer 1 must not silently map to deer.

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/features/model_manager/model_manager_controller_test.dart
```

- [ ] **Step 3: Implement mapping logic and MD3 dialog**

Show `.pt` trust warning before first model load: model files can contain executable serialized content; only open models from trusted sources. Persist mapping metadata in project state once approved.

- [ ] **Step 4: Verify tests**

```bash
flutter test test/features/model_manager/model_manager_controller_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/inference lib/features/model_manager test/features/model_manager
git commit -m "feat: add pt model manager and class mapping"
```

---

### Task 8: Convert predictions into editable annotations and support batch inference

**Files:**
- Create: `lib/features/annotation_workspace/prediction_importer.dart`
- Modify: `lib/features/annotation_workspace/annotation_workspace_controller.dart`
- Test: `test/features/annotation_workspace/prediction_importer_test.dart`

**Interfaces:**
- Produces `annotationsFromPredictions(image, detections, mapping, modelId)`.
- Adds controller methods `inferCurrentImage` and `inferImages(Iterable<String> imageIds)` with cancellable incremental processing.

- [ ] **Step 1: Write failing conversion test**

A detection `(x1:100,y1:120,x2:420,y2:500)` maps to `BoundingBox(left:100,top:120,width:320,height:380)`, source `prediction`, confidence retained, category chosen only via `ClassMapping`.

- [ ] **Step 2: Verify failure**

```bash
flutter test test/features/annotation_workspace/prediction_importer_test.dart
```

- [ ] **Step 3: Implement conversion and incremental batch loop**

After each successful image prediction, execute a command that appends predictions and persist the project. Cancellation stops before the next image and retains completed images.

- [ ] **Step 4: Verify milestone**

```bash
cd inference_runtime && python -m pytest -q
cd ..
flutter test
flutter analyze
flutter build windows
```

Expected: all pass/build succeeds when local dependencies are installed.

- [ ] **Step 5: Commit**

```bash
git add lib/features/annotation_workspace test/features/annotation_workspace
git commit -m "feat: add editable YOLO pt predictions"
```

## Plan self-review result

- Covers direct `.pt` loading, Ultralytics/PyTorch worker, versioned IPC, model metadata, class mapping, prediction conversion, auto/cpu/cuda device policy, cancellation, local-only execution, and trust warning.
- No task converts `.pt` to ONNX.
- No task makes Python installation a packaged-user requirement; runtime bundling is handled in the release plan.
