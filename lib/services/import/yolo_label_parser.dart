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
  if (classId == null || classId < 0 || values.any((v) => v == null || !v.isFinite)) {
    throw const FormatException('YOLO detection row contains invalid numeric values');
  }
  final v = values.cast<double>();
  return YoloLabelRow(classId, v[0], v[1], v[2], v[3]);
}
