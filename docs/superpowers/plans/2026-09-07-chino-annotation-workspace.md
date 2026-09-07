# Chino Annotation Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn an imported Chino project into a productive desktop annotation workspace with image navigation, selection, box creation/move/resize/delete, category reassignment, zoom/pan, and undo/redo.

**Architecture:** The canvas is a pure projection of immutable project state plus transient viewport/gesture state. Editing operations are represented as commands that produce a new project snapshot and can be inverted for undo/redo; the UI never writes YOLO files directly.

**Tech Stack:** Flutter/Dart, Material 3, Riverpod, CustomPainter, InteractiveViewer-style transform math, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-07-chino-design.md`

## Global Constraints

- Bounding boxes are the only first-release annotation primitive.
- Geometry is stored in image-space coordinates and bounded by image dimensions.
- Imported, manual, and prediction annotations are all editable.
- Keyboard shortcuts must not interfere with focused text fields.
- Layout uses left dataset browser, center canvas, right object/class inspector.
- Narrower windows may collapse side panels.

## Planned File Structure

```text
lib/features/annotation_workspace/
  annotation_workspace_screen.dart
  annotation_workspace_controller.dart
  annotation_workspace_state.dart
  annotation_canvas.dart
  annotation_painter.dart
  canvas_transform.dart
  gesture_state.dart
  dataset_browser.dart
  annotation_inspector.dart
  shortcut_bindings.dart
lib/domain/commands/
  edit_command.dart
  create_annotation_command.dart
  update_box_command.dart
  reassign_category_command.dart
  delete_annotation_command.dart
  undo_redo_stack.dart
lib/domain/category/category_editor.dart

test/features/annotation_workspace/...
test/domain/commands/...
```

---

### Task 1: Implement undoable annotation commands

**Files:**
- Create: `lib/domain/commands/edit_command.dart`
- Create: `lib/domain/commands/create_annotation_command.dart`
- Create: `lib/domain/commands/update_box_command.dart`
- Create: `lib/domain/commands/reassign_category_command.dart`
- Create: `lib/domain/commands/delete_annotation_command.dart`
- Create: `lib/domain/commands/undo_redo_stack.dart`
- Test: `test/domain/commands/undo_redo_stack_test.dart`

**Interfaces:**
- Produces: `abstract interface class EditCommand { ChinoProject apply(ChinoProject project); ChinoProject revert(ChinoProject project); }`.
- Produces: `UndoRedoStack.execute`, `undo`, `redo`, `canUndo`, `canRedo`.

- [ ] **Step 1: Write failing command-stack tests**

```dart
final stack = UndoRedoStack();
final afterCreate = stack.execute(project, CreateAnnotationCommand(annotation));
expect(afterCreate.annotations, contains(annotation));
final undone = stack.undo(afterCreate);
expect(undone.annotations, isEmpty);
final redone = stack.redo(undone);
expect(redone.annotations.single.id, annotation.id);
```

- [ ] **Step 2: Run failing test**

```bash
flutter test test/domain/commands/undo_redo_stack_test.dart
```

Expected: FAIL because command types do not exist.

- [ ] **Step 3: Implement commands as immutable list replacements**

Use `copyWith` methods added to `ChinoProject`/`Annotation` as necessary. Every command stores sufficient old/new data to invert itself; command application must never mutate existing lists.

- [ ] **Step 4: Verify undo/redo behavior**

```bash
flutter test test/domain/commands/undo_redo_stack_test.dart
```

Expected: PASS including create, move/resize, category change, delete, and redo invalidation after a new command.

- [ ] **Step 5: Commit**

```bash
git add lib/domain test/domain
git commit -m "feat: add undoable annotation commands"
```

---

### Task 2: Implement canvas transform math

**Files:**
- Create: `lib/features/annotation_workspace/canvas_transform.dart`
- Test: `test/features/annotation_workspace/canvas_transform_test.dart`

**Interfaces:**
- Produces: `CanvasTransform.fit`, `imageToViewport`, `viewportToImage`, `zoomAround`, `panBy`.

- [ ] **Step 1: Write failing transform tests**

```dart
final transform = CanvasTransform.fit(
  imageSize: const Size(1000, 500),
  viewportSize: const Size(500, 500),
);
expect(transform.imageToViewport(const Offset(500, 250)), const Offset(250, 250));
expect(transform.viewportToImage(const Offset(250, 250)), const Offset(500, 250));
```

- [ ] **Step 2: Verify failure**

```bash
flutter test test/features/annotation_workspace/canvas_transform_test.dart
```

- [ ] **Step 3: Implement scale + translation transform**

`fit` uses `min(viewportWidth/imageWidth, viewportHeight/imageHeight)` and centers the image. `zoomAround` must preserve the image point under the cursor/focal point. Clamp scale to `0.05..32.0`.

- [ ] **Step 4: Verify tests**

```bash
flutter test test/features/annotation_workspace/canvas_transform_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/annotation_workspace test/features/annotation_workspace
git commit -m "feat: add annotation canvas transform math"
```

---

### Task 3: Render image and annotations with selection handles

**Files:**
- Create: `lib/features/annotation_workspace/annotation_canvas.dart`
- Create: `lib/features/annotation_workspace/annotation_painter.dart`
- Test: `test/features/annotation_workspace/annotation_canvas_test.dart`

**Interfaces:**
- Consumes: `DatasetImage`, `List<Annotation>`, `CanvasTransform`.
- Produces widget callbacks: `onSelect(String? annotationId)`, `onCreate(BoundingBox box)`, `onUpdate(String id, BoundingBox box)`.

- [ ] **Step 1: Write failing widget test for selection and render count**

Render an in-memory test image asset or fixture, pass two annotations, tap inside one transformed box, and assert `onSelect` receives that id.

- [ ] **Step 2: Run failing test**

```bash
flutter test test/features/annotation_workspace/annotation_canvas_test.dart
```

- [ ] **Step 3: Implement painter and hit testing**

Draw each box from image-space through `CanvasTransform`. Draw selected box with 8 resize handles. Hit testing priority: selected resize handle, topmost box interior, background.

- [ ] **Step 4: Verify widget tests**

```bash
flutter test test/features/annotation_workspace/annotation_canvas_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/annotation_workspace test/features/annotation_workspace
git commit -m "feat: render selectable annotation canvas"
```

---

### Task 4: Implement create, move, and resize gestures with geometry bounds

**Files:**
- Create: `lib/features/annotation_workspace/gesture_state.dart`
- Modify: `lib/features/annotation_workspace/annotation_canvas.dart`
- Modify: `lib/domain/annotation/bounding_box.dart`
- Test: `test/features/annotation_workspace/annotation_gestures_test.dart`
- Test: `test/domain/bounding_box_test.dart`

**Interfaces:**
- Adds `BoundingBox.clampToImage(width, height)` and `normalizedEdges` helper.

- [ ] **Step 1: Add failing tests for out-of-bounds and reverse-drag boxes**

```dart
const box = BoundingBox(left: -10, top: 20, width: 100, height: 100);
final clamped = box.clampToImage(imageWidth: 80, imageHeight: 60);
expect(clamped.left, 0);
expect(clamped.top, 20);
expect(clamped.width, 80);
expect(clamped.height, 40);
```

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/domain/bounding_box_test.dart test/features/annotation_workspace/annotation_gestures_test.dart
```

- [ ] **Step 3: Implement gesture modes**

Gesture modes: idle, creating, moving, resizing(handle). Convert pointer deltas to image space before geometry changes. Ignore accidental create drags smaller than 4 logical pixels on screen. Clamp final boxes to image bounds.

- [ ] **Step 4: Verify gesture tests**

```bash
flutter test test/domain/bounding_box_test.dart test/features/annotation_workspace/annotation_gestures_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/annotation lib/features/annotation_workspace test
git commit -m "feat: edit bounding boxes on canvas"
```

---

### Task 5: Build workspace controller and three-pane Material 3 layout

**Files:**
- Create: `lib/features/annotation_workspace/annotation_workspace_state.dart`
- Create: `lib/features/annotation_workspace/annotation_workspace_controller.dart`
- Create: `lib/features/annotation_workspace/dataset_browser.dart`
- Create: `lib/features/annotation_workspace/annotation_inspector.dart`
- Create: `lib/features/annotation_workspace/annotation_workspace_screen.dart`
- Modify: `lib/features/home/home_screen.dart`
- Test: `test/features/annotation_workspace/annotation_workspace_screen_test.dart`

**Interfaces:**
- Produces controller methods: `selectImage`, `selectAnnotation`, `createAnnotation`, `updateAnnotationBox`, `deleteSelected`, `reassignSelected`, `undo`, `redo`, `nextImage`, `previousImage`.

- [ ] **Step 1: Write failing screen test**

Verify three regions exist at >=1200 px width: dataset browser, canvas, inspector. Verify selecting next image changes filename and annotation count.

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/features/annotation_workspace/annotation_workspace_screen_test.dart
```

- [ ] **Step 3: Implement controller over command stack**

State includes current project, selectedImageId, selectedAnnotationId, transform, left/right panel visibility. Persist project changes through the existing project store after command execution using a debounced save hook; tests inject a fake persistence callback.

- [ ] **Step 4: Implement responsive three-pane UI**

At wide widths show left + center + right. Under 1000 px, use toggle buttons/drawers for side panels while retaining the center canvas. Use Material 3 `NavigationDrawer`/`Card`/`ListTile`/`DropdownMenu` where appropriate.

- [ ] **Step 5: Verify tests and analysis**

```bash
flutter test test/features/annotation_workspace
flutter analyze
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features test/features
git commit -m "feat: add Chino annotation workspace"
```

---

### Task 6: Add category management with safe YOLO index remapping

**Files:**
- Create: `lib/domain/category/category_editor.dart`
- Modify: `lib/features/annotation_workspace/annotation_inspector.dart`
- Modify: `lib/features/annotation_workspace/annotation_workspace_controller.dart`
- Test: `test/domain/category/category_editor_test.dart`

**Interfaces:**
- Produces: `renameCategory`, `appendCategory`, `reorderCategories` returning a new `ChinoProject` with contiguous export indices and unchanged stable category ids.

- [ ] **Step 1: Write failing remapping test**

Create categories A(index 0), B(index 1), annotation referencing B stable id; reorder to B,A and assert annotation still references B while B now has yoloIndex 0.

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/domain/category/category_editor_test.dart
```

- [ ] **Step 3: Implement stable-id based category editing**

Never rewrite annotation category references by integer index. Reorder only `Category.yoloIndex`; refuse category deletion while referenced unless caller explicitly supplies a replacement category id.

- [ ] **Step 4: Verify tests**

```bash
flutter test test/domain/category/category_editor_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/category lib/features/annotation_workspace test/domain/category
git commit -m "feat: manage annotation categories safely"
```

---

### Task 7: Add desktop shortcuts and final workspace smoke tests

**Files:**
- Create: `lib/features/annotation_workspace/shortcut_bindings.dart`
- Modify: `lib/features/annotation_workspace/annotation_workspace_screen.dart`
- Test: `test/features/annotation_workspace/shortcuts_test.dart`

**Interfaces:**
- Shortcuts: Delete = delete selected box; Ctrl+Z = undo; Ctrl+Shift+Z/Ctrl+Y = redo; A/D or Left/Right = previous/next image when no text input is focused; F = fit image.

- [ ] **Step 1: Write failing shortcut tests**

Focus the canvas, send Delete/Ctrl+Z and verify controller calls. Focus a `TextField`, send Delete and verify text editing is not intercepted.

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/features/annotation_workspace/shortcuts_test.dart
```

- [ ] **Step 3: Implement `Shortcuts` + `Actions` bindings with focus guards**

Use Flutter intents/actions rather than global raw-key handlers. Only image navigation and deletion actions activate when the primary focus is not an editable text control.

- [ ] **Step 4: Verify complete workspace milestone**

```bash
flutter test
flutter analyze
flutter build windows
```

Expected: PASS/build succeeds.

- [ ] **Step 5: Commit**

```bash
git add lib/features/annotation_workspace test/features/annotation_workspace
git commit -m "feat: add desktop annotation shortcuts"
```

## Plan self-review result

- Covers manual box creation/edit/delete, navigation, zoom/pan transform, selection, inspector, category assignment, undo/redo, responsive three-pane layout, keyboard workflow.
- Uses image-space geometry throughout and commands for all durable edits.
- Prediction-specific behavior is deferred to the inference plan but uses the same annotation domain model and editor.
