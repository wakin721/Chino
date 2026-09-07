# Security

## PyTorch model trust

Chino supports direct loading of Ultralytics/PyTorch `.pt` model files. Python model serialization formats can be unsafe when the file comes from an untrusted source. Treat a `.pt` file similarly to executable code: only open models obtained from sources you trust.

Chino intentionally does not add arbitrary `torch.load` compatibility fallbacks. Model loading is delegated to the pinned Ultralytics/PyTorch runtime.

## Local processing

The v1 inference worker communicates with Chino through stdin/stdout and does not start a network listener. Images and model weights are processed locally by default and are not uploaded by Chino.

## Reporting

Please report suspected security issues privately to the repository owner rather than publishing exploit details in a public issue before a fix is available.
