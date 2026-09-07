import 'inference_protocol.dart';
import 'inference_worker.dart';

class InferenceModelMetadata {
  const InferenceModelMetadata({required this.modelId, required this.names, required this.device});
  final String modelId;
  final Map<int, String> names;
  final String device;
}

class InferenceService {
  const InferenceService(this.worker);
  final InferenceWorker worker;

  Future<InferenceModelMetadata> loadModel(String modelPath, {String device = 'auto'}) async {
    final response = await worker.request({'action': 'load_model', 'model_path': modelPath, 'device': device});
    final raw = response.raw;
    final namesRaw = raw['names'] as Map? ?? const {};
    return InferenceModelMetadata(
      modelId: raw['model_id'] as String,
      names: {for (final entry in namesRaw.entries) int.parse(entry.key.toString()): entry.value.toString()},
      device: raw['device'] as String,
    );
  }

  Future<InferenceResponse> predict(String imagePath, {double confidence = 0.25, double iou = 0.7}) => worker.request({
        'action': 'predict',
        'image_path': imagePath,
        'confidence': confidence,
        'iou': iou,
      });
}
