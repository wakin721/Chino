import '../annotation/annotation.dart';
import '../category/category.dart';
import '../dataset/dataset_image.dart';
import 'chino_project.dart';

Map<String, Object?> encodeProject(ChinoProject project) => {
      'version': 1,
      'project': {
        'id': project.id,
        'name': project.name,
        'categories': project.categories.map((e) => e.toJson()).toList(),
        'images': project.images.map((e) => e.toJson()).toList(),
        'annotations': project.annotations.map((e) => e.toJson()).toList(),
      },
    };

ChinoProject decodeProject(Map<String, Object?> json) {
  final version = json['version'];
  if (version != 1) throw FormatException('Unsupported Chino project version: $version');
  final raw = Map<String, Object?>.from(json['project'] as Map);
  return ChinoProject(
    id: raw['id'] as String,
    name: raw['name'] as String,
    categories: (raw['categories'] as List).map((e) => Category.fromJson(Map<String, Object?>.from(e as Map))).toList(),
    images: (raw['images'] as List).map((e) => DatasetImage.fromJson(Map<String, Object?>.from(e as Map))).toList(),
    annotations: (raw['annotations'] as List).map((e) => Annotation.fromJson(Map<String, Object?>.from(e as Map))).toList(),
  );
}
