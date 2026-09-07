# Chino Foundation & Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable Windows-first Flutter Material 3 shell that can create/open a Chino project, import plain images or conventional YOLO detection datasets, parse `data.yaml`/`.txt` labels, and persist project state atomically.

**Architecture:** Flutter owns all project/domain state. Importers convert external YOLO/image data into image-space domain objects; YOLO normalized values never remain as the internal editing representation. Persistence uses a versioned JSON manifest written atomically through a temp file and rename.

**Tech Stack:** Flutter/Dart, Material 3, `flutter_riverpod`, `file_picker`, `path`, `yaml`, `uuid`, `image`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-07-chino-design.md`

## Global Constraints

- Windows desktop is the primary first-release target.
- Use Material 3.
- Support JPG, JPEG, and PNG import.
- Support standard YOLO detection rows: `class_id x_center y_center width height`.
- Support conventional `images/...` + `labels/...`, sibling image/label folders, and same-directory pairs.
- `data.yaml` names are authoritative when present.
- Missing label file means zero annotations, not failure.
- Do not modify source YOLO labels in place during normal editing.
- Internal box geometry uses image-space coordinates.
- Project persistence is versioned and atomic.

## Planned File Structure

```text
lib/
  main.dart
  app/app.dart
  app/theme/chino_theme.dart
  domain/project/chino_project.dart
  domain/project/project_manifest_codec.dart
  domain/dataset/dataset_image.dart
  domain/dataset/dataset_split.dart
  domain/annotation/bounding_box.dart
  domain/annotation/annotation.dart
  domain/category/category.dart
  features/home/home_screen.dart
  features/import/import_controller.dart
  features/import/import_summary.dart
  services/import/image_probe.dart
  services/import/yolo_dataset_discovery.dart
  services/import/yolo_label_parser.dart
  services/import/yolo_import_service.dart
  services/project/project_store.dart

test/
  domain/bounding_box_test.dart
  domain/project_manifest_codec_test.dart
  services/yolo_label_parser_test.dart
  services/yolo_dataset_discovery_test.dart
  services/yolo_import_service_test.dart
  services/project_store_test.dart
  features/home/home_screen_test.dart

test/fixtures/yolo_standard/...
```

---

### Task 1: Scaffold Flutter Windows app and Material 3 shell

**Files:**
- Create/modify: Flutter scaffold files generated at repository root
- Modify: `pubspec.yaml`
- Create: `lib/app/app.dart`
- Create: `lib/app/theme/chino_theme.dart`
- Create: `lib/features/home/home_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/features/home/home_screen_test.dart`

**Interfaces:**
- Produces: `ChinoApp`, `ChinoTheme.light()`, `ChinoTheme.dark()`, `HomeScreen`.

- [ ] **Step 1: Scaffold only the Windows platform and add dependencies**

```bash
flutter create --platforms=windows --project-name chino .
flutter pub add flutter_riverpod file_picker path yaml uuid image
```

- [ ] **Step 2: Replace generated widget test with a failing Material 3 shell test**

```dart
import 'package:chino/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Chino starts with a Material 3 home shell', (tester) async {
    await tester.pumpWidget(const ChinoApp());
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(find.text('Chino'), findsOneWidget);
    expect(find.text('Import dataset'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test and verify it fails**

```bash
flutter test test/features/home/home_screen_test.dart
```

Expected: FAIL because `ChinoApp` does not yet exist.

- [ ] **Step 4: Implement the minimal app shell**

```dart
// lib/app/theme/chino_theme.dart
import 'package:flutter/material.dart';

abstract final class ChinoTheme {
  static ThemeData light() => ThemeData(useMaterial3: true, brightness: Brightness.light);
  static ThemeData dark() => ThemeData(useMaterial3: true, brightness: Brightness.dark);
}
```

```dart
// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chino')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.folder_open),
            label: const Text('Import dataset'),
          ),
        ),
      );
}
```

```dart
// lib/app/app.dart
import 'package:chino/app/theme/chino_theme.dart';
import 'package:chino/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChinoApp extends StatelessWidget {
  const ChinoApp({super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
        child: MaterialApp(
          title: 'Chino',
          theme: ChinoTheme.light(),
          darkTheme: ChinoTheme.dark(),
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
        ),
      );
}
```

```dart
// lib/main.dart
import 'package:chino/app/app.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ChinoApp());
```

- [ ] **Step 5: Verify test and static analysis**

```bash
flutter test test/features/home/home_screen_test.dart
flutter analyze
```

Expected: PASS and no analyzer errors.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib test windows
git commit -m "feat: scaffold Chino Material 3 desktop app"
```

---

### Task 2: Define domain types and image-space box invariants

**Files:**
- Create: `lib/domain/dataset/dataset_split.dart`
- Create: `lib/domain/dataset/dataset_image.dart`
- Create: `lib/domain/category/category.dart`
- Create: `lib/domain/annotation/bounding_box.dart`
- Create: `lib/domain/annotation/annotation.dart`
- Create: `lib/domain/project/chino_project.dart`
- Test: `test/domain/bounding_box_test.dart`

**Interfaces:**
- Produces: `DatasetSplit`, `DatasetImage`, `Category`, `BoundingBox`, `Annotation`, `AnnotationSource`, `ChinoProject`.
- `BoundingBox.fromYolo(...)` and `toYolo(...)` are the single conversion boundary used by import/export code.

- [ ] **Step 1: Write failing coordinate-conversion tests**

```dart
import 'package:chino/domain/annotation/bounding_box.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts YOLO normalized coordinates to image coordinates', () {
    final box = BoundingBox.fromYolo(
      xCenter: 0.5,
      yCenter: 0.5,
      width: 0.25,
      height: 0.5,
      imageWidth: 800,
      imageHeight: 600,
    );
    expect(box.left, 300);
    expect(box.top, 150);
    expect(box.width, 200);
    expect(box.height, 300);
  });

  test('round trips image box to YOLO values', () {
    const box = BoundingBox(left: 300, top: 150, width: 200, height: 300);
    final yolo = box.toYolo(imageWidth: 800, imageHeight: 600);
    expect(yolo, closeToList(<double>[0.5, 0.5, 0.25, 0.5], 1e-9));
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/domain/bounding_box_test.dart
```

Expected: FAIL because `BoundingBox` does not exist.

- [ ] **Step 3: Implement focused immutable domain types**

```dart
// lib/domain/annotation/bounding_box.dart
class BoundingBox {
  const BoundingBox({required this.left, required this.top, required this.width, required this.height});
  final double left;
  final double top;
  final double width;
  final double height;

  factory BoundingBox.fromYolo({
    required double xCenter,
    required double yCenter,
    required double width,
    required double height,
    required int imageWidth,
    required int imageHeight,
  }) {
    final w = width * imageWidth;
    final h = height * imageHeight;
    return BoundingBox(
      left: xCenter * imageWidth - w / 2,
      top: yCenter * imageHeight - h / 2,
      width: w,
      height: h,
    );
  }

  List<double> toYolo({required int imageWidth, required int imageHeight}) => <double>[
        (left + width / 2) / imageWidth,
        (top + height / 2) / imageHeight,
        width / imageWidth,
        height / imageHeight,
      ];
}
```

```dart
// lib/domain/dataset/dataset_split.dart
enum DatasetSplit { train, val, test, unassigned }
```

```dart
// lib/domain/category/category.dart
class Category {
  const Category({required this.id, required this.yoloIndex, required this.name});
  final String id;
  final int yoloIndex;
  final String name;
}
```

```dart
// lib/domain/annotation/annotation.dart
import 'bounding_box.dart';

enum AnnotationSource { manual, imported, prediction }

class Annotation {
  const Annotation({
    required this.id,
    required this.imageId,
    required this.categoryId,
    required this.box,
    required this.source,
    this.confidence,
    this.modelId,
  });
  final String id;
  final String imageId;
  final String categoryId;
  final BoundingBox box;
  final AnnotationSource source;
  final double? confidence;
  final String? modelId;
}
```

```dart
// lib/domain/dataset/dataset_image.dart
import 'dataset_split.dart';

class DatasetImage {
  const DatasetImage({
    required this.id,
    required this.path,
    required this.filename,
    required this.width,
    required this.height,
    this.split = DatasetSplit.unassigned,
  });
  final String id;
  final String path;
  final String filename;
  final int width;
  final int height;
  final DatasetSplit split;
}
```

```dart
// lib/domain/project/chino_project.dart
import '../annotation/annotation.dart';
import '../category/category.dart';
import '../dataset/dataset_image.dart';

class ChinoProject {
  const ChinoProject({
    required this.id,
    required this.name,
    required this.images,
    required this.categories,
    required this.annotations,
  });
  final String id;
  final String name;
  final List<DatasetImage> images;
  final List<Category> categories;
  final List<Annotation> annotations;
}
```

- [ ] **Step 4: Run tests and analysis**

```bash
flutter test test/domain/bounding_box_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain test/domain
git commit -m "feat: add Chino project domain model"
```

---

### Task 3: Parse YOLO labels and `data.yaml` class names

**Files:**
- Create: `lib/services/import/yolo_label_parser.dart`
- Create: `lib/services/import/yolo_names_parser.dart`
- Test: `test/services/yolo_label_parser_test.dart`
- Test: `test/services/yolo_names_parser_test.dart`

**Interfaces:**
- Produces: `YoloLabelRow parseYoloLabelRow(String line)` and `List<String> parseYoloNames(String yamlText)`.
- `YoloLabelRow` exposes `classId`, `xCenter`, `yCenter`, `width`, `height`.

- [ ] **Step 1: Write failing parser tests**

```dart
import 'package:chino/services/import/yolo_label_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a five-field YOLO detection row', () {
    final row = parseYoloLabelRow('2 0.5 0.4 0.2 0.1');
    expect(row.classId, 2);
    expect(row.xCenter, 0.5);
  });

  test('rejects negative class ids and missing fields', () {
    expect(() => parseYoloLabelRow('-1 0.5 0.4 0.2 0.1'), throwsFormatException);
    expect(() => parseYoloLabelRow('0 0.5 0.4'), throwsFormatException);
  });
}
```

```dart
import 'package:chino/services/import/yolo_names_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses names as a list', () {
    expect(parseYoloNames('names: [bird, deer]'), <String>['bird', 'deer']);
  });

  test('parses integer keyed names map in index order', () {
    expect(parseYoloNames('names:\n  1: deer\n  0: bird\n'), <String>['bird', 'deer']);
  });
}
```

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/services/yolo_label_parser_test.dart test/services/yolo_names_parser_test.dart
```

Expected: FAIL because parser files do not exist.

- [ ] **Step 3: Implement strict parsing**

```dart
// lib/services/import/yolo_label_parser.dart
class YoloLabelRow {
  const YoloLabelRow(this.classId, this.xCenter, this.yCenter, this.width, this.height);
  final int classId;
  final double xCenter;
  final double yCenter;
  final double width;
  final double height;
}

YoloLabelRow parseYoloLabelRow(String line) {
  final parts = line.trim().split(RegExp(r'\s+'));
  if (parts.length != 5) throw const FormatException('YOLO detection row must contain 5 fields');
  final classId = int.tryParse(parts[0]);
  final values = parts.skip(1).map(double.tryParse).toList();
  if (classId == null || classId < 0 || values.any((v) => v == null || !v!.isFinite)) {
    throw const FormatException('YOLO detection row contains invalid numeric values');
  }
  final v = values.cast<double>();
  return YoloLabelRow(classId, v[0], v[1], v[2], v[3]);
}
```

```dart
// lib/services/import/yolo_names_parser.dart
import 'package:yaml/yaml.dart';

List<String> parseYoloNames(String yamlText) {
  final root = loadYaml(yamlText);
  final names = root is YamlMap ? root['names'] : null;
  if (names is YamlList) return names.map((e) => e.toString()).toList(growable: false);
  if (names is YamlMap) {
    final indexed = <int, String>{};
    for (final entry in names.entries) {
      final index = int.tryParse(entry.key.toString());
      if (index == null || index < 0) throw const FormatException('Invalid class index in data.yaml');
      indexed[index] = entry.value.toString();
    }
    if (indexed.isEmpty) return const [];
    final maxIndex = indexed.keys.reduce((a, b) => a > b ? a : b);
    return List<String>.generate(maxIndex + 1, (i) {
      final name = indexed[i];
      if (name == null) throw const FormatException('Class indices in data.yaml must be contiguous');
      return name;
    });
  }
  throw const FormatException('data.yaml must contain a names list or map');
}
```

- [ ] **Step 4: Verify parser tests**

```bash
flutter test test/services/yolo_label_parser_test.dart test/services/yolo_names_parser_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/import test/services
git commit -m "feat: parse YOLO labels and class names"
```

---

### Task 4: Discover dataset layouts and probe image dimensions

**Files:**
- Create: `lib/services/import/image_probe.dart`
- Create: `lib/services/import/yolo_dataset_discovery.dart`
- Test: `test/services/yolo_dataset_discovery_test.dart`
- Create fixtures: `test/fixtures/yolo_standard/data.yaml`, `images/train/a.png`, `labels/train/a.txt`, `images/val/b.png`, `labels/val/b.txt`

**Interfaces:**
- Produces: `Future<ImageProbeResult> probeImage(String path)`.
- Produces: `Future<YoloDatasetLayout> discoverYoloDataset(String rootPath)` where layout contains `dataYamlPath`, `imageEntries`, and matched `labelPath`/`DatasetSplit`.

- [ ] **Step 1: Create a tiny fixture generator test helper and failing layout test**

```dart
import 'dart:io';
import 'package:chino/domain/dataset/dataset_split.dart';
import 'package:chino/services/import/yolo_dataset_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches images/train with labels/train and preserves split', () async {
    final layout = await discoverYoloDataset('test/fixtures/yolo_standard');
    final train = layout.imageEntries.singleWhere((e) => e.imagePath.endsWith('a.png'));
    expect(train.labelPath?.endsWith('labels${Platform.pathSeparator}train${Platform.pathSeparator}a.txt'), isTrue);
    expect(train.split, DatasetSplit.train);
  });
}
```

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/services/yolo_dataset_discovery_test.dart
```

Expected: FAIL because discovery is not implemented.

- [ ] **Step 3: Implement deterministic conventional-layout discovery**

```dart
// lib/services/import/yolo_dataset_discovery.dart
import 'dart:io';
import 'package:chino/domain/dataset/dataset_split.dart';
import 'package:path/path.dart' as p;

class DiscoveredImage {
  const DiscoveredImage({required this.imagePath, required this.labelPath, required this.split});
  final String imagePath;
  final String? labelPath;
  final DatasetSplit split;
}

class YoloDatasetLayout {
  const YoloDatasetLayout({required this.dataYamlPath, required this.imageEntries});
  final String? dataYamlPath;
  final List<DiscoveredImage> imageEntries;
}

Future<YoloDatasetLayout> discoverYoloDataset(String rootPath) async {
  final root = Directory(rootPath);
  final yaml = File(p.join(rootPath, 'data.yaml'));
  final imagesRoot = Directory(p.join(rootPath, 'images'));
  final entries = <DiscoveredImage>[];
  final allowed = <String>{'.jpg', '.jpeg', '.png'};

  await for (final entity in (await imagesRoot.exists() ? imagesRoot : root).list(recursive: true)) {
    if (entity is! File || !allowed.contains(p.extension(entity.path).toLowerCase())) continue;
    final relative = p.relative(entity.path, from: imagesRoot.path);
    final first = p.split(relative).firstOrNull;
    final split = switch (first) {
      'train' => DatasetSplit.train,
      'val' => DatasetSplit.val,
      'test' => DatasetSplit.test,
      _ => DatasetSplit.unassigned,
    };
    final labelRelative = p.setExtension(relative, '.txt');
    final conventionalLabel = File(p.join(rootPath, 'labels', labelRelative));
    final sameDirLabel = File(p.setExtension(entity.path, '.txt'));
    final labelPath = await conventionalLabel.exists()
        ? conventionalLabel.path
        : await sameDirLabel.exists()
            ? sameDirLabel.path
            : null;
    entries.add(DiscoveredImage(imagePath: entity.path, labelPath: labelPath, split: split));
  }
  entries.sort((a, b) => a.imagePath.compareTo(b.imagePath));
  return YoloDatasetLayout(dataYamlPath: await yaml.exists() ? yaml.path : null, imageEntries: entries);
}
```

The implementation must use an explicit helper instead of `firstOrNull` if the resolved Dart SDK does not expose that extension; keep the public interface unchanged.

- [ ] **Step 4: Implement image dimension probing with the `image` package**

```dart
// lib/services/import/image_probe.dart
import 'dart:io';
import 'package:image/image.dart' as img;

class ImageProbeResult {
  const ImageProbeResult(this.width, this.height);
  final int width;
  final int height;
}

Future<ImageProbeResult> probeImage(String path) async {
  final decoded = img.decodeImage(await File(path).readAsBytes());
  if (decoded == null) throw FormatException('Unsupported or corrupt image: $path');
  return ImageProbeResult(decoded.width, decoded.height);
}
```

- [ ] **Step 5: Verify discovery and analysis**

```bash
flutter test test/services/yolo_dataset_discovery_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/import test/services test/fixtures
git commit -m "feat: discover YOLO dataset layouts"
```

---

### Task 5: Import a dataset into Chino domain objects with warnings instead of batch aborts

**Files:**
- Create: `lib/features/import/import_summary.dart`
- Create: `lib/services/import/yolo_import_service.dart`
- Test: `test/services/yolo_import_service_test.dart`

**Interfaces:**
- Consumes: `discoverYoloDataset`, `parseYoloNames`, `parseYoloLabelRow`, `probeImage`, domain types.
- Produces: `Future<ImportSummary> YoloImportService.importDirectory(String rootPath)`.
- `ImportSummary` exposes `project`, `warnings`, `failedFiles`, `importedImageCount`, `importedAnnotationCount`.

- [ ] **Step 1: Write a failing integration-style import test**

```dart
import 'package:chino/domain/annotation/annotation.dart';
import 'package:chino/services/import/yolo_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports classes, images, labels, and missing-label images', () async {
    final result = await YoloImportService().importDirectory('test/fixtures/yolo_standard');
    expect(result.project.categories.map((e) => e.name), containsAll(<String>['bird', 'deer']));
    expect(result.project.images, isNotEmpty);
    expect(result.project.annotations.every((a) => a.source == AnnotationSource.imported), isTrue);
    expect(result.failedFiles, isEmpty);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
flutter test test/services/yolo_import_service_test.dart
```

Expected: FAIL because `YoloImportService` does not exist.

- [ ] **Step 3: Implement import summary and service**

```dart
// lib/features/import/import_summary.dart
import '../../domain/project/chino_project.dart';

class ImportSummary {
  const ImportSummary({required this.project, required this.warnings, required this.failedFiles});
  final ChinoProject project;
  final List<String> warnings;
  final List<String> failedFiles;
  int get importedImageCount => project.images.length;
  int get importedAnnotationCount => project.annotations.length;
}
```

Implement `YoloImportService.importDirectory` with this exact flow:

```dart
final layout = await discoverYoloDataset(rootPath);
final names = layout.dataYamlPath == null
    ? <String>[]
    : parseYoloNames(await File(layout.dataYamlPath!).readAsString());
for (final discovered in layout.imageEntries) {
  // probe dimensions; on corrupt image record failedFiles and continue
  // read non-empty label lines; on malformed row record warning and continue neighboring rows
  // create placeholder categories class_N when an observed id exceeds names length
  // convert each valid YOLO row with BoundingBox.fromYolo(...)
  // source = AnnotationSource.imported
}
```

Use `Uuid().v4()` for stable ids created during import. If no YAML name exists for an observed id, create `class_<index>`; do not reorder existing ids.

- [ ] **Step 4: Verify import behavior**

```bash
flutter test test/services/yolo_import_service_test.dart
flutter test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/import lib/services/import test/services
git commit -m "feat: import YOLO datasets into Chino projects"
```

---

### Task 6: Add versioned project JSON codec and atomic persistence

**Files:**
- Create: `lib/domain/project/project_manifest_codec.dart`
- Create: `lib/services/project/project_store.dart`
- Test: `test/domain/project_manifest_codec_test.dart`
- Test: `test/services/project_store_test.dart`

**Interfaces:**
- Produces: `Map<String, Object?> encodeProject(ChinoProject project)`.
- Produces: `ChinoProject decodeProject(Map<String, Object?> json)` supporting manifest version `1`.
- Produces: `Future<void> ProjectStore.save(ChinoProject project, String path)` and `Future<ChinoProject> load(String path)`.

- [ ] **Step 1: Write failing round-trip and atomic-save tests**

```dart
final encoded = encodeProject(project);
expect(encoded['version'], 1);
final decoded = decodeProject(encoded);
expect(decoded.images.single.width, project.images.single.width);
expect(decoded.annotations.single.box.left, project.annotations.single.box.left);
```

```dart
final dir = await Directory.systemTemp.createTemp('chino_store_test');
final path = p.join(dir.path, 'sample.chino.json');
await ProjectStore().save(project, path);
expect(await File(path).exists(), isTrue);
expect(await File('$path.tmp').exists(), isFalse);
final loaded = await ProjectStore().load(path);
expect(loaded.id, project.id);
```

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/domain/project_manifest_codec_test.dart test/services/project_store_test.dart
```

Expected: FAIL because codec/store do not exist.

- [ ] **Step 3: Implement manifest version 1 and strict decoding**

The encoded top level must be:

```json
{
  "version": 1,
  "project": {
    "id": "...",
    "name": "...",
    "categories": [],
    "images": [],
    "annotations": []
  }
}
```

Decode enum values from their string names and reject unsupported manifest versions with `FormatException('Unsupported Chino project version: <n>')`.

- [ ] **Step 4: Implement atomic store**

```dart
Future<void> save(ChinoProject project, String path) async {
  final target = File(path);
  final temp = File('$path.tmp');
  await temp.parent.create(recursive: true);
  await temp.writeAsString(jsonEncode(encodeProject(project)), flush: true);
  if (await target.exists()) await target.delete();
  await temp.rename(path);
}
```

`load` reads UTF-8 JSON, requires a map root, and delegates to `decodeProject`.

- [ ] **Step 5: Verify all tests**

```bash
flutter test
flutter analyze
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/project lib/services/project test/domain test/services
git commit -m "feat: persist Chino projects atomically"
```

---

### Task 7: Wire import/open actions into the home screen

**Files:**
- Create: `lib/features/import/import_controller.dart`
- Modify: `lib/features/home/home_screen.dart`
- Test: `test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `YoloImportService`, `ProjectStore`, `file_picker`.
- Produces: Riverpod state containing `ChinoProject? project`, `bool busy`, and latest import warnings/errors.

- [ ] **Step 1: Extend widget test for imported-project summary state**

```dart
expect(find.text('No project open'), findsOneWidget);
expect(find.text('Import dataset'), findsOneWidget);
expect(find.text('Open project'), findsOneWidget);
```

Add a provider override with a fake controller and verify that loaded state renders `2 images` and `1 annotation`.

- [ ] **Step 2: Run and verify failure**

```bash
flutter test test/features/home/home_screen_test.dart
```

Expected: FAIL because the controller/status UI is absent.

- [ ] **Step 3: Implement controller with injected services**

```dart
class ImportState {
  const ImportState({this.project, this.busy = false, this.messages = const []});
  final ChinoProject? project;
  final bool busy;
  final List<String> messages;
}
```

Expose methods `Future<void> importDataset()`, `Future<void> openProject()`, `Future<void> saveProjectAs()`; file-picker cancellation returns without changing state.

- [ ] **Step 4: Update HomeScreen to show project counts and non-blocking warnings**

Use Material 3 `FilledButton.icon`, `OutlinedButton.icon`, `Card`, and `SnackBar`/inline status text. Disable mutation buttons while `busy` is true.

- [ ] **Step 5: Verify full foundation milestone**

```bash
flutter test
flutter analyze
flutter build windows
```

Expected: tests pass, analysis clean, Windows build succeeds.

- [ ] **Step 6: Commit**

```bash
git add lib/features test/features
git commit -m "feat: wire dataset import into Chino home screen"
```

## Plan self-review result

- Spec coverage in this plan: Windows/Material 3 shell, image import, conventional YOLO layout discovery, `data.yaml` names, label parsing, missing-label handling, image-space geometry, local project model, atomic versioned persistence.
- Deferred by design to later plans: interactive annotation canvas, class-management UX, `.pt` inference, YOLO export, packaging/runtime distribution.
- Type consistency checked: import/export boundary uses `BoundingBox.fromYolo`/`toYolo`; project ownership remains in Flutter; `ImportSummary` and `ProjectStore` are consumed by the home controller.
- No source label file is rewritten by any task in this plan.
