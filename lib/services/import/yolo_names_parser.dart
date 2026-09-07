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
