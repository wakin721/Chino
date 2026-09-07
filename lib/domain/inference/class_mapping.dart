import '../category/category.dart';

class ClassMapping {
  const ClassMapping(this.modelToCategory);
  final Map<int, String> modelToCategory;
  String? categoryIdFor(int modelClassId) => modelToCategory[modelClassId];

  static ClassMapping byExactName(Map<int, String> modelNames, List<Category> categories) {
    final byName = {for (final category in categories) category.name: category.id};
    return ClassMapping({
      for (final entry in modelNames.entries)
        if (byName[entry.value] != null) entry.key: byName[entry.value]!,
    });
  }
}
