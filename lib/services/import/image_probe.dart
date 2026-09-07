import 'dart:io';
import 'package:image/image.dart' as img;

class ImageProbeResult {
  const ImageProbeResult(this.width, this.height);
  final int width;
  final int height;
}

Future<ImageProbeResult> probeImage(String path) async {
  final decoded = img.decodeImage(await File(path).readAsBytes());
  if (decoded == null) throw FormatException('Unsupported or corrupt image: $path');
  return ImageProbeResult(decoded.width, decoded.height);
}
