import 'dart:io';
import 'package:path/path.dart' as p;
import '../../domain/dataset/dataset_split.dart';

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

DatasetSplit _splitFor(String relativePath) {
  final parts = p.split(relativePath);
  if (parts.isEmpty) return DatasetSplit.unassigned;
  return switch (parts.first.toLowerCase()) {
    'train' => DatasetSplit.train,
    'val' || 'valid' => DatasetSplit.val,
    'test' => DatasetSplit.test,
    _ => DatasetSplit.unassigned,
  };
}

Future<YoloDatasetLayout> discoverYoloDataset(String rootPath) async {
  final root = Directory(rootPath);
  if (!await root.exists()) throw FileSystemException('Dataset directory does not exist', rootPath);
  final imagesRoot = Directory(p.join(rootPath, 'images'));
  final scanRoot = await imagesRoot.exists() ? imagesRoot : root;
  final yaml = File(p.join(rootPath, 'data.yaml'));
  final allowed = <String>{'.jpg', '.jpeg', '.png'};
  final entries = <DiscoveredImage>[];

  await for (final entity in scanRoot.list(recursive: true, followLinks: false)) {
    if (entity is! File || !allowed.contains(p.extension(entity.path).toLowerCase())) continue;
    final relative = p.relative(entity.path, from: scanRoot.path);
    final split = _splitFor(relative);
    final conventional = File(p.join(rootPath, 'labels', p.setExtension(relative, '.txt')));
    final sameDirectory = File(p.setExtension(entity.path, '.txt'));
    String? labelPath;
    if (await conventional.exists()) {
      labelPath = conventional.path;
    } else if (await sameDirectory.exists()) {
      labelPath = sameDirectory.path;
    }
    entries.add(DiscoveredImage(imagePath: entity.path, labelPath: labelPath, split: split));
  }
  entries.sort((a, b) => a.imagePath.compareTo(b.imagePath));
  return YoloDatasetLayout(dataYamlPath: await yaml.exists() ? yaml.path : null, imageEntries: entries);
}
