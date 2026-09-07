class BoundingBox {
  const BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  factory BoundingBox.fromYolo({
    required double xCenter,
    required double yCenter,
    required double width,
    required double height,
    required int imageWidth,
    required int imageHeight,
  }) {
    final boxWidth = width * imageWidth;
    final boxHeight = height * imageHeight;
    return BoundingBox(
      left: xCenter * imageWidth - boxWidth / 2,
      top: yCenter * imageHeight - boxHeight / 2,
      width: boxWidth,
      height: boxHeight,
    );
  }

  List<double> toYolo({required int imageWidth, required int imageHeight}) => <double>[
        (left + width / 2) / imageWidth,
        (top + height / 2) / imageHeight,
        width / imageWidth,
        height / imageHeight,
      ];

  BoundingBox clampToImage({required int imageWidth, required int imageHeight}) {
    final l = left.clamp(0.0, imageWidth.toDouble());
    final t = top.clamp(0.0, imageHeight.toDouble());
    final r = right.clamp(0.0, imageWidth.toDouble());
    final b = bottom.clamp(0.0, imageHeight.toDouble());
    return BoundingBox(left: l, top: t, width: (r - l).clamp(0.0, imageWidth.toDouble()), height: (b - t).clamp(0.0, imageHeight.toDouble()));
  }

  Map<String, Object?> toJson() => {'left': left, 'top': top, 'width': width, 'height': height};

  factory BoundingBox.fromJson(Map<String, Object?> json) => BoundingBox(
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}
