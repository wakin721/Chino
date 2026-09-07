class InferenceException implements Exception {
  const InferenceException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'InferenceException($code): $message';
}

class InferenceDetection {
  const InferenceDetection({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
  final int classId;
  final String className;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

class InferenceResponse {
  const InferenceResponse({required this.requestId, this.action, this.detections = const []});
  final String requestId;
  final String? action;
  final List<InferenceDetection> detections;
}

InferenceResponse decodeInferenceResponse(Map<String, Object?> json) {
  if (json['protocol'] != 1) throw const InferenceException('unsupported_protocol', 'Only protocol version 1 is supported.');
  final requestId = json['request_id'] as String?;
  if (requestId == null || requestId.isEmpty) throw const InferenceException('invalid_response', 'Missing request_id.');
  if (json['ok'] != true) {
    final error = json['error'] is Map ? Map<String, Object?>.from(json['error'] as Map) : const <String, Object?>{};
    throw InferenceException(error['code']?.toString() ?? 'worker_error', error['message']?.toString() ?? 'Inference worker error.');
  }
  final rawDetections = (json['detections'] as List?) ?? const [];
  final detections = rawDetections.map((raw) {
    final d = Map<String, Object?>.from(raw as Map);
    return InferenceDetection(
      classId: d['class_id'] as int,
      className: d['class_name'] as String,
      confidence: (d['confidence'] as num).toDouble(),
      x1: (d['x1'] as num).toDouble(),
      y1: (d['y1'] as num).toDouble(),
      x2: (d['x2'] as num).toDouble(),
      y2: (d['y2'] as num).toDouble(),
    );
  }).toList(growable: false);
  return InferenceResponse(requestId: requestId, action: json['action'] as String?, detections: detections);
}
