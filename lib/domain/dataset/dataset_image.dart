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

  Map<String, Object?> toJson() => {
        'id': id,
        'path': path,
        'filename': filename,
        'width': width,
        'height': height,
        'split': split.name,
      };

  factory DatasetImage.fromJson(Map<String, Object?> json) => DatasetImage(
        id: json['id'] as String,
        path: json['path'] as String,
        filename: json['filename'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        split: DatasetSplit.values.byName((json['split'] as String?) ?? 'unassigned'),
      );
}
