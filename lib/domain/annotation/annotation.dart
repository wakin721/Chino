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

  Annotation copyWith({String? categoryId, BoundingBox? box}) => Annotation(
        id: id,
        imageId: imageId,
        categoryId: categoryId ?? this.categoryId,
        box: box ?? this.box,
        source: source,
        confidence: confidence,
        modelId: modelId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'imageId': imageId,
        'categoryId': categoryId,
        'box': box.toJson(),
        'source': source.name,
        if (confidence != null) 'confidence': confidence,
        if (modelId != null) 'modelId': modelId,
      };

  factory Annotation.fromJson(Map<String, Object?> json) => Annotation(
        id: json['id'] as String,
        imageId: json['imageId'] as String,
        categoryId: json['categoryId'] as String,
        box: BoundingBox.fromJson(Map<String, Object?>.from(json['box'] as Map)),
        source: AnnotationSource.values.byName(json['source'] as String),
        confidence: (json['confidence'] as num?)?.toDouble(),
        modelId: json['modelId'] as String?,
      );
}
