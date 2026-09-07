class Category {
  const Category({required this.id, required this.yoloIndex, required this.name});

  final String id;
  final int yoloIndex;
  final String name;

  Category copyWith({int? yoloIndex, String? name}) => Category(
        id: id,
        yoloIndex: yoloIndex ?? this.yoloIndex,
        name: name ?? this.name,
      );

  Map<String, Object?> toJson() => {'id': id, 'yoloIndex': yoloIndex, 'name': name};

  factory Category.fromJson(Map<String, Object?> json) => Category(
        id: json['id'] as String,
        yoloIndex: json['yoloIndex'] as int,
        name: json['name'] as String,
      );
}
