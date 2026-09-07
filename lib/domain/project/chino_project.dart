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

  ChinoProject copyWith({
    String? name,
    List<DatasetImage>? images,
    List<Category>? categories,
    List<Annotation>? annotations,
  }) => ChinoProject(
        id: id,
        name: name ?? this.name,
        images: images ?? this.images,
        categories: categories ?? this.categories,
        annotations: annotations ?? this.annotations,
      );
}
