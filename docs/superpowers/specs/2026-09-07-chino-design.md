# Chino Design Specification

Date: 2026-09-07
Status: Approved design baseline
Repository: `wakin721/Chino`

## 1. Product definition

Chino is a Flutter desktop application for object-detection dataset annotation. The first release targets Windows and uses a Material 3 user interface. It supports importing images together with existing YOLO-format labels, manually creating and editing bounding boxes, running local YOLO inference directly from Ultralytics-compatible `.pt` model weights, reviewing predictions, and exporting a standard YOLO detection dataset.

The primary workflow is:

1. Import images or an existing YOLO dataset.
2. Load existing YOLO annotations when present.
3. Optionally load a `.pt` YOLO model and run automatic detection.
4. Review, create, resize, move, relabel, or delete bounding boxes.
5. Save project state locally.
6. Export images, labels, and `data.yaml` in YOLO format.

## 2. First-release scope

### In scope

- Windows desktop as the primary supported platform.
- Flutter UI using Material 3.
- JPG, JPEG, PNG image import.
- Folder and multi-file image import.
- Import of standard YOLO object-detection labels in `.txt` format.
- Import of class names from `data.yaml` when available.
- Recognition of common YOLO layouts, including:
  - `images/train`, `labels/train`, `images/val`, `labels/val`, optional `test`.
  - sibling `images/` and `labels/` directories.
  - image and matching `.txt` label in the same directory.
- Bounding-box annotation only.
- Class creation, rename, reorder safeguards, and class assignment.
- Local YOLO inference from Ultralytics-compatible `.pt` weights.
- Prediction confidence display and configurable confidence threshold.
- Conversion of predictions into editable annotations.
- Standard YOLO detection export with normalized coordinates.
- Preservation of train/val/test split metadata when imported from a YOLO dataset where practical.
- Local project persistence.
- Keyboard and mouse interactions appropriate for a desktop annotation tool.

### Explicitly out of scope for the first release

- Segmentation polygons.
- Pose/keypoint annotation.
- Model training inside Chino.
- Cloud inference or cloud synchronization.
- Multi-user collaboration.
- Mobile-first UI.
- Direct editing of arbitrary PyTorch checkpoints that are not loadable by Ultralytics.

The architecture must leave room for segmentation and pose support later without forcing the first release to carry their editing complexity.

## 3. Technical architecture

Chino uses a layered architecture with four main boundaries:

1. Flutter presentation layer.
2. Application/domain layer for projects, images, annotations, classes, splits, and commands.
3. File and dataset services for import, persistence, and export.
4. A local inference runtime responsible for loading `.pt` weights and returning detections.

Flutter remains the source of truth for project state and annotations. The inference runtime is a replaceable worker, not the owner of project data.

Suggested Flutter structure:

```text
lib/
  app/
    app.dart
    theme/
    routing/
  core/
    errors/
    io/
    logging/
    commands/
  domain/
    project/
    dataset_image/
    annotation/
    category/
    split/
    inference/
  features/
    home/
    import/
    annotation_workspace/
    model_manager/
    export/
    settings/
  services/
    project_service.dart
    import_service.dart
    yolo_label_service.dart
    inference_service.dart
    export_service.dart
  widgets/
```

The bundled inference worker is maintained outside the Flutter domain layer, for example:

```text
inference_runtime/
  chino_inference/
    __main__.py
    protocol.py
    model_loader.py
    predict.py
    errors.py
  requirements.lock
  packaging/
```

## 4. Material 3 UI

The desktop workspace uses a three-region layout:

- Left: dataset browser with image thumbnails, split/state indicators, search/filter controls.
- Center: annotation canvas with zoom, pan, bounding-box creation, resize handles, selection, and overlays.
- Right: object list, class selector, confidence for model predictions, and annotation properties.

A top app bar or command bar contains project, import, model, inference, save, and export actions. The layout should adapt to narrower windows by allowing side panels to collapse.

Material 3 components and color roles should be used rather than custom widget styling where possible. Dark and light themes should both remain viable, even if the initial release defaults to the system theme.

## 5. Domain model

### Project

A project contains:

- project id and display name;
- project file version;
- class list;
- image records;
- annotation records;
- source dataset metadata;
- split assignments;
- selected inference-model metadata;
- user preferences that are project-specific.

### Dataset image

Each image record contains:

- stable internal id;
- absolute or project-relative source path;
- filename;
- width and height;
- optional split: train, val, test, or unassigned;
- annotation status;
- import source metadata.

### Category

Each category contains:

- stable internal id;
- YOLO class index used for import/export;
- display name;
- optional UI metadata.

Internal annotation references should use a stable category id. YOLO integer indices are serialization details and must be remapped deliberately when classes change.

### Bounding-box annotation

Each annotation contains:

- stable id;
- image id;
- category id;
- box geometry in image-space coordinates;
- source: manual, imported, or prediction;
- optional prediction confidence;
- optional model identifier;
- creation/update metadata needed for undo/redo and persistence.

Image-space coordinates are preferred internally. YOLO normalized coordinates are produced only at import/export boundaries. This avoids accumulating rounding error during editing.

## 6. YOLO dataset import

The import service must support both plain image import and YOLO-aware dataset import.

### Dataset discovery

When the user selects a dataset directory, Chino should:

1. Search for a `data.yaml` in the selected root and sensible nearby locations.
2. Parse `names` whether represented as a sequence or integer-keyed map.
3. Resolve train/val/test image roots when declared by the YAML and locally accessible.
4. Detect conventional `images/...` and corresponding `labels/...` structures.
5. Match annotations by image stem.
6. Treat a missing label file as an image with zero annotations, not an import failure.
7. Report malformed labels without discarding valid neighboring files.

### Label format

The first release accepts YOLO detection rows:

```text
class_id x_center y_center width height
```

Coordinates are normalized to the image dimensions.

Import validation must reject or flag:

- non-numeric values;
- negative class ids;
- missing fields;
- non-finite values;
- boxes that cannot be mapped to valid image geometry.

Small floating-point overshoots caused by upstream exporters may be clamped only within a documented tolerance. Clearly invalid boxes should be surfaced to the user rather than silently rewritten.

### Class-name behavior

If `data.yaml` exists, its `names` mapping is authoritative for imported YOLO class indices.

If no class-name source exists, Chino may create placeholder names such as `class_0`, `class_1`, etc., based on observed ids. The UI must make these placeholders explicit and editable.

### Duplicate and conflict handling

Re-importing the same dataset must not silently duplicate every image and box. The application should identify previously imported paths and require an explicit merge/replace decision when content overlaps.

## 7. `.pt` YOLO inference

### Runtime choice

Flutter/Dart does not directly execute ordinary Ultralytics PyTorch `.pt` weights. Chino therefore uses a bundled local inference worker based on Python, PyTorch, and Ultralytics. The user should not be required to install or configure Python separately in a packaged release.

The worker must support Ultralytics-compatible object-detection `.pt` weights that can be loaded by the bundled Ultralytics version. Chino should report an unsupported or incompatible checkpoint clearly instead of attempting unsafe deserialization fallbacks.

### Process boundary

The Flutter application launches and supervises the local inference worker. Communication should use a versioned, machine-readable protocol over stdin/stdout or a loopback-only IPC mechanism. For the first release, a line-delimited JSON request/response protocol over stdin/stdout is preferred because it avoids port management and firewall issues.

Example request semantics:

```json
{
  "protocol": 1,
  "request_id": "...",
  "action": "predict",
  "model_path": "C:/models/best.pt",
  "image_path": "C:/dataset/images/001.jpg",
  "confidence": 0.25,
  "iou": 0.7,
  "device": "auto"
}
```

Example response semantics:

```json
{
  "protocol": 1,
  "request_id": "...",
  "ok": true,
  "image_width": 1920,
  "image_height": 1080,
  "detections": [
    {
      "class_id": 0,
      "class_name": "bird",
      "confidence": 0.91,
      "x1": 100.0,
      "y1": 120.0,
      "x2": 420.0,
      "y2": 500.0
    }
  ]
}
```

The concrete protocol may be extended, but protocol versioning and request ids are mandatory.

### Model-class mapping

On model load, Chino reads model class names through the worker. If they match current project classes, predictions map directly. If they differ, the user must be shown a mapping step or an explicit option to append model classes. Chino must not silently bind a model class index to an unrelated project class just because the integer ids coincide.

### Prediction behavior

Predictions are initially marked as `prediction` source and remain editable. Users can accept them by editing or through a future explicit review action. Export includes current visible/saved annotations regardless of whether they originated manually, from import, or from a prediction, unless the UI introduces an explicit rejected state.

Batch inference should process images incrementally so results already produced are retained if the user cancels later images.

### Device selection

The runtime should support:

- `auto` as the default;
- CPU fallback;
- CUDA when available to the bundled/runtime PyTorch stack.

The first release should not claim unsupported accelerators. Device capability is detected by the inference worker and displayed to Flutter.

## 8. Annotation editor behavior

Core operations:

- create box by drag;
- select box;
- move box;
- resize from handles;
- delete box;
- change category;
- navigate previous/next image;
- zoom and pan without altering geometry;
- fit image to viewport;
- undo and redo annotation commands.

Geometry must remain bounded by image dimensions. Very small accidental boxes should either be prevented at creation time using a small screen-space threshold or removed through an explicit validation rule.

Keyboard shortcuts should avoid conflicts with text-entry widgets and should be documented in the UI.

## 9. Project persistence

Chino uses a versioned project manifest stored locally. The project file records paths and metadata needed to reopen the workspace without rewriting the source dataset on every edit.

Autosave should persist project metadata and annotations to a Chino-owned project file. Source YOLO labels are not modified in place by default. Writing back into source data is intentionally deferred; export is the supported way to create a new YOLO dataset.

Project persistence must be atomic: write a temporary file, flush it, then replace the previous manifest. A corrupt partial save must not destroy the last valid project file.

## 10. YOLO export

The export service creates a standard object-detection dataset, for example:

```text
export_root/
  data.yaml
  images/
    train/
    val/
    test/
  labels/
    train/
    val/
    test/
```

Unused split directories may be omitted.

For each annotation Chino writes:

```text
class_id x_center y_center width height
```

All coordinates are normalized and derived from current image-space boxes.

Export requirements:

- class ids are contiguous and match `data.yaml`;
- each image has a corresponding label file when needed by the chosen export convention;
- zero-object images are preserved;
- train/val/test assignments are preserved from imported datasets when possible;
- unassigned images require an explicit export policy, such as export to train or keep as an unsplit flat dataset;
- paths in `data.yaml` are portable within the exported dataset;
- export occurs into a new destination by default and does not overwrite source files silently.

The exporter should validate all images, class mappings, and boxes before committing the final output. A temporary export directory followed by a final rename is preferred to avoid half-written datasets.

## 11. Error handling

Errors are grouped into actionable categories:

- import errors;
- malformed label warnings;
- unsupported image errors;
- model-load errors;
- inference runtime errors;
- device/runtime errors;
- persistence errors;
- export validation/errors.

Batch operations should provide a summary containing successful, skipped, warning, and failed counts. One bad image or label should not abort the whole import unless project integrity would be compromised.

The inference worker must return structured error codes and concise messages. Python tracebacks may be written to diagnostic logs, but the normal UI should show a user-actionable explanation.

## 12. Security and trust boundaries

PyTorch `.pt` loading can involve Python object deserialization. Chino must treat model files as trusted local input and warn users not to open untrusted `.pt` files. The runtime should use the safest loading path supported by the pinned Ultralytics/PyTorch versions and should not add arbitrary compatibility fallbacks that execute unknown code.

The inference worker should run locally, should not expose a network listener by default, and should not upload images or model weights.

## 13. Packaging strategy

The Windows release should package:

- Flutter Windows executable and assets;
- the inference worker;
- pinned Python runtime and required packages, or an equivalent self-contained worker bundle;
- PyTorch/Ultralytics versions validated together.

The packaging mechanism should allow a CPU baseline build first. GPU acceleration can be provided when the packaged runtime can support it reliably without forcing all users to install a development environment.

The repository should keep the inference protocol stable enough that alternative runtimes can be introduced later without rewriting the Flutter annotation editor.

## 14. Testing strategy

### Flutter unit tests

- YOLO coordinate conversion.
- Bounding-box validation and clamping rules.
- Class-id remapping.
- Project serialization/version migration.
- Dataset layout detection.
- Export path construction.
- Undo/redo command behavior.

### Flutter widget tests

- workspace selection state;
- class reassignment;
- image navigation;
- panel state;
- error and warning presentation.

### Import/export fixture tests

Maintain small fixture datasets covering:

- standard train/val structure;
- flat image/label pairs;
- missing label files;
- empty label files;
- malformed rows;
- YAML names as list;
- YAML names as map;
- Unicode and whitespace-containing paths.

A round-trip test should import a fixture, persist it, export it, and verify semantic equivalence within defined float tolerance.

### Inference worker tests

- protocol parsing;
- invalid request handling;
- model load failure;
- prediction normalization;
- worker cancellation/shutdown;
- model class metadata;
- CPU smoke test with a small supported `.pt` fixture where licensing and repository size permit.

### End-to-end smoke test

A packaged Windows smoke test should verify:

1. launch Chino;
2. import a small YOLO dataset;
3. display imported labels;
4. load a compatible `.pt` model;
5. infer at least one image;
6. edit a prediction;
7. export;
8. verify exported YOLO labels and `data.yaml`.

## 15. Implementation milestones

Milestone 1: Flutter shell and project/domain model.

Milestone 2: image + YOLO label import and project persistence.

Milestone 3: bounding-box annotation canvas and class management.

Milestone 4: bundled `.pt` inference worker and Flutter IPC integration.

Milestone 5: YOLO export and validation.

Milestone 6: packaging, tests, keyboard workflow polish, and release documentation.

## 16. Acceptance criteria for the first usable release

The release is considered usable when a Windows user can, without manually installing Python:

- open Chino;
- import a conventional YOLO detection dataset and see its existing boxes and class names;
- import plain images into a project;
- load a compatible Ultralytics `.pt` object-detection model;
- run inference and see editable predicted boxes;
- manually create, move, resize, relabel, and delete boxes;
- save and reopen the project without losing annotations;
- export a valid YOLO detection dataset with correct normalized labels and `data.yaml`.

No first-release acceptance criterion depends on segmentation, pose, training, cloud services, or collaborative editing.
