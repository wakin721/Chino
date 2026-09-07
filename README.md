# Chino

Chino is a Windows-first Flutter desktop application for object-detection dataset annotation. It uses Material 3, imports existing YOLO detection datasets and labels, can run compatible Ultralytics `.pt` models locally, and exports standard YOLO datasets.

## Current v1 workflow

1. Start Chino and choose **Import dataset**.
2. Select either a directory of JPG/JPEG/PNG images or a YOLO dataset root.
3. Existing `data.yaml` class names and matching YOLO `.txt` labels are loaded automatically.
4. In the workspace, drag on an empty part of the image to create a box. Drag an existing box to move it; drag its lower-right handle to resize it.
5. Select a box to change its class or delete it. `Ctrl+Z` / `Ctrl+Y` provide undo/redo.
6. Choose **Load .pt model** to load a trusted Ultralytics detection model. Chino maps classes by exact name and asks before adding previously unknown model classes.
7. Choose **Detect** to run inference on the current image. Predictions become normal editable Chino annotations.
8. Save a `.chino.json` project or export a standard YOLO dataset.

## Supported YOLO import layouts

Conventional split layout:

```text
dataset/
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

Sibling flat layout:

```text
dataset/
  images/
    001.jpg
  labels/
    001.txt
```

Image and matching label in one directory are also accepted. Missing label files are treated as zero-object images. Detection labels must use:

```text
class_id x_center y_center width height
```

## Direct `.pt` inference

Chino does not convert `.pt` files to ONNX. The Flutter application communicates with a local Python worker over versioned JSON-lines stdin/stdout. The worker loads Ultralytics-compatible object-detection `.pt` weights and returns image-space boxes, class names and confidences.

Development mode uses a local Python command with the `inference_runtime` directory as its working directory. Packaged Windows builds prefer an `inference_runtime/python.exe` directory next to `chino.exe`, so end users do not need to install Python separately.

Pinned Windows runtime for the current v1 packaging recipe:

- Python 3.12.10 embeddable x64
- PyTorch 2.14.0
- torchvision 0.29.0
- Ultralytics 8.4.142

## Development

Prerequisites: Flutter stable with Windows desktop support; Visual Studio C++ desktop workload for Windows builds; Python 3.12 for inference-worker development.

```powershell
flutter create --platforms=windows --project-name chino .
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Run worker unit tests without installing PyTorch because the tests use fakes:

```powershell
python -m pip install pytest
python -m pytest inference_runtime/tests -q
```

To exercise a real `.pt` model during development:

```powershell
python -m pip install -r inference_runtime/requirements.lock
```

Build the Windows application and bundled inference runtime:

```powershell
flutter build windows --release
./tools/package_inference_runtime.ps1
```

The packaging script downloads the official CPython embeddable distribution and installs the pinned runtime packages into the release directory.

## Export

Chino exports normalized YOLO detection labels and `data.yaml`, preserving train/val/test split information where present. Source labels are never rewritten in place during ordinary editing.

## Current limitations

- Bounding-box object detection only; segmentation and pose are not implemented.
- Model training is not implemented.
- Cloud synchronization and collaboration are not implemented.
- Batch inference UI is not yet part of the first workspace; detection currently runs on the selected image.
- The first release is Windows-first.

## Security

Only load `.pt` files from trusted sources. See [SECURITY.md](SECURITY.md).
