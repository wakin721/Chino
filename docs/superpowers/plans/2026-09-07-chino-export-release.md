# Chino Export & Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Chino with validated YOLO dataset export, release packaging for Windows, end-to-end tests, and user-facing documentation.

**Architecture:** Export is a pure transformation from validated Chino project state to a staged filesystem tree, followed by an atomic destination swap where possible. Windows packaging combines the Flutter app with the local inference worker/runtime so users can run `.pt` inference without separately installing Python.

**Tech Stack:** Flutter/Dart, YAML emission, filesystem staging, Windows build tooling, Python worker packaging, GitHub Actions, flutter_test, pytest.

**Spec:** `docs/superpowers/specs/2026-09-07-chino-design.md`

## Global Constraints

- Export standard YOLO detection labels only.
- Export class ids must be contiguous and match `data.yaml`.
- Preserve zero-object images.
- Preserve imported train/val/test assignments when possible.
- Do not silently overwrite source datasets.
- Validate before finalizing export.
- Packaged Windows users must not need a separate Python installation.

## Planned File Structure

```text
lib/services/export/
  export_options.dart
  export_validator.dart
  yolo_export_service.dart
lib/features/export/
  export_controller.dart
  export_dialog.dart
lib/core/io/
  staged_directory.dart

test/services/export/...
test/features/export/...

tools/package_inference_runtime.ps1
.github/workflows/windows.yml
README.md
SECURITY.md
```

---

### Task 1: Define export validation and options

**Files:**
- Create: `lib/services/export/export_options.dart`
- Create: `lib/services/export/export_validator.dart`
- Test: `test/services/export/export_validator_test.dart`

**Interfaces:**
- Produces `ExportOptions(destinationPath, unassignedPolicy, overwriteExisting)`.
- Produces `ExportValidationResult(errors,warnings)`.
- `UnassignedPolicy`: `train`, `flat`, `reject`.

- [ ] **Step 1: Write failing validation tests**

Verify duplicate YOLO indices, missing category references, boxes outside image bounds, missing source image files, and unassigned images under `reject` produce errors.

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/services/export/export_validator_test.dart
```

- [ ] **Step 3: Implement validator**

Require category indices to equal exactly `0..n-1`. Validate finite positive box dimensions and box edges within image dimensions. Check every annotation category id exists.

- [ ] **Step 4: Verify tests**

```bash
flutter test test/services/export/export_validator_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/export test/services/export
git commit -m "feat: validate YOLO dataset export"
```

---

### Task 2: Implement staged directory helper and YOLO writer

**Files:**
- Create: `lib/core/io/staged_directory.dart`
- Create: `lib/services/export/yolo_export_service.dart`
- Test: `test/services/export/yolo_export_service_test.dart`

**Interfaces:**
- Produces `Future<ExportResult> YoloExportService.export(ChinoProject project, ExportOptions options)`.

- [ ] **Step 1: Write failing fixture export test**

Build a temp Chino project with train/val images and one zero-object image. Export and assert:

```text
images/train/a.png
labels/train/a.txt
images/val/b.png
labels/val/b.txt
data.yaml
```

The label line must numerically equal `class_id x_center y_center width height` from `BoundingBox.toYolo` within `1e-6`.

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/services/export/yolo_export_service_test.dart
```

- [ ] **Step 3: Implement staged export**

Write into `<destination>.chino-staging-<uuid>`. Copy image bytes, emit label files, emit portable YAML paths, then rename staging to final destination. If final destination exists and overwrite is false, throw before writing. Always clean staging on failure.

- [ ] **Step 4: Emit deterministic `data.yaml`**

```yaml
path: .
train: images/train
val: images/val
names:
  0: bird
  1: deer
```

Include `test:` only when used. Under flat policy, emit `images/` and `labels/` and omit split keys that do not apply.

- [ ] **Step 5: Verify tests**

```bash
flutter test test/services/export/yolo_export_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/io lib/services/export test/services/export
git commit -m "feat: export validated YOLO datasets"
```

---

### Task 3: Add Material 3 export flow

**Files:**
- Create: `lib/features/export/export_controller.dart`
- Create: `lib/features/export/export_dialog.dart`
- Modify: `lib/features/annotation_workspace/annotation_workspace_screen.dart`
- Test: `test/features/export/export_dialog_test.dart`

**Interfaces:**
- Export dialog selects destination, displays validation errors/warnings, chooses unassigned policy, and starts export.

- [ ] **Step 1: Write failing dialog test**

Verify export button is disabled when validator has errors and enabled after choosing a valid policy/destination.

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/features/export/export_dialog_test.dart
```

- [ ] **Step 3: Implement controller/dialog**

Use `file_picker` for destination folder. Show counts for images/annotations/classes and split counts before export. Require explicit confirmation before overwriting an existing destination.

- [ ] **Step 4: Verify tests**

```bash
flutter test test/features/export/export_dialog_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/export lib/features/annotation_workspace test/features/export
git commit -m "feat: add YOLO export workflow"
```

---

### Task 4: Add semantic round-trip test

**Files:**
- Create: `test/integration/yolo_round_trip_test.dart`

**Interfaces:**
- Consumes existing import and export services.

- [ ] **Step 1: Write round-trip integration test**

Import `test/fixtures/yolo_standard`, export to temp, import exported dataset again. Compare category names, image count, split assignments, annotation class identity, and box geometry to within `1e-6` normalized tolerance.

- [ ] **Step 2: Run test**

```bash
flutter test test/integration/yolo_round_trip_test.dart
```

Expected: PASS; fix import/export defects if it fails.

- [ ] **Step 3: Commit**

```bash
git add test/integration
git commit -m "test: verify YOLO import export round trip"
```

---

### Task 5: Package the Python inference runtime for Windows

**Files:**
- Create: `tools/package_inference_runtime.ps1`
- Modify: `pubspec.yaml` or Windows CMake packaging config as required
- Create: `inference_runtime/requirements.lock` from pinned tested versions

**Interfaces:**
- Produces a worker bundle at a deterministic path consumed by `InferenceWorker` in release mode.

- [ ] **Step 1: Pin validated runtime versions**

Create a lock file with the exact Python, Ultralytics, and PyTorch versions used by CI. Do not use unbounded `>=` ranges for release packaging.

- [ ] **Step 2: Implement packaging script**

The PowerShell script must:

```powershell
$ErrorActionPreference = 'Stop'
# create clean staging directory
# install pinned worker dependencies into isolated environment
# package python worker into a self-contained executable/directory
# copy bundle under build/windows/.../runner/Release/inference_runtime
# run worker --self-test/ping before returning success
```

Use a packaging mechanism validated with PyTorch/Ultralytics on Windows (for example an embedded Python distribution plus installed site-packages if single-file freezing proves unreliable). Favor reliability over single-exe size.

- [ ] **Step 3: Make Flutter locate development and packaged worker paths explicitly**

Development: configured Python executable + `-m chino_inference`. Release: bundled runtime path adjacent to Chino executable. Missing runtime must produce an actionable UI error.

- [ ] **Step 4: Build and smoke test**

```powershell
flutter build windows
powershell -ExecutionPolicy Bypass -File tools/package_inference_runtime.ps1
```

Launch packaged worker and send a ping request; expected clean protocol response.

- [ ] **Step 5: Commit**

```bash
git add tools inference_runtime/requirements.lock pubspec.yaml windows lib/services/inference
git commit -m "build: package Chino inference runtime"
```

---

### Task 6: Add Windows CI

**Files:**
- Create: `.github/workflows/windows.yml`

**Interfaces:**
- CI runs Dart analysis/tests, Python worker tests, and Windows Flutter build on pull requests and main.

- [ ] **Step 1: Create workflow**

Workflow steps:

```yaml
- checkout
- setup Flutter stable
- flutter pub get
- flutter analyze
- flutter test
- setup Python 3.12
- install inference runtime test dependencies
- python -m pytest inference_runtime/tests -q
- flutter build windows
```

Use dependency caching where supported. Runtime packaging can be a separate job because PyTorch bundle size may make every PR unnecessarily slow.

- [ ] **Step 2: Validate workflow syntax locally where possible and push**

After push, inspect GitHub Actions result and fix only evidenced failures.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/windows.yml
git commit -m "ci: test Chino on Windows"
```

---

### Task 7: Write user and security documentation

**Files:**
- Create/replace: `README.md`
- Create: `SECURITY.md`

**Interfaces:**
- Documentation covers import, annotation, `.pt` inference, export, development, packaging, and model trust risk.

- [ ] **Step 1: Write README with concrete first-run flow**

Required sections: What Chino is; screenshots placeholder only if actual screenshots are committed; supported dataset layouts; `.pt` model requirements; annotation controls; YOLO export structure; development prerequisites; Windows build commands; current limitations.

- [ ] **Step 2: Write SECURITY.md**

State that `.pt`/PyTorch model files can be unsafe if obtained from untrusted sources, models/images are processed locally by default, and users should report security issues through the repository's supported channel.

- [ ] **Step 3: Verify commands/documentation against actual project**

Do not document segmentation, pose, cloud sync, or training as implemented.

- [ ] **Step 4: Commit**

```bash
git add README.md SECURITY.md
git commit -m "docs: document Chino usage and model security"
```

---

### Task 8: Final end-to-end release verification

**Files:**
- Modify only files required by evidenced failures.

**Interfaces:**
- Produces a release-candidate Windows build satisfying the design acceptance criteria.

- [ ] **Step 1: Run all automated checks**

```bash
flutter pub get
flutter analyze
flutter test
cd inference_runtime && python -m pytest -q
```

Expected: all pass.

- [ ] **Step 2: Build packaged Windows release**

```powershell
flutter build windows --release
powershell -ExecutionPolicy Bypass -File tools/package_inference_runtime.ps1
```

- [ ] **Step 3: Perform manual acceptance smoke test**

On a clean Windows environment or clean VM:

1. launch Chino;
2. import standard YOLO fixture and confirm existing boxes/classes;
3. import plain images;
4. load a trusted compatible `.pt` detection model;
5. run inference on one image;
6. edit prediction and create/delete a manual box;
7. save and reopen project;
8. export YOLO dataset;
9. inspect/import exported dataset and confirm semantic correctness.

- [ ] **Step 4: Verify Git status and final test evidence**

```bash
git status --short
```

Expected: clean working tree after fixes/commits.

- [ ] **Step 5: Commit any final evidenced fixes separately**

```bash
git add <specific-files>
git commit -m "fix: resolve release verification issue"
```

## Plan self-review result

- Covers export validation, normalized label serialization, class/index integrity, split preservation, zero-object images, staging/atomic completion, Windows runtime bundling, CI, documentation, security warning, and end-to-end acceptance.
- Source datasets are never silently overwritten.
- Release packaging explicitly retains direct `.pt` inference and removes any requirement for end users to install Python manually.
