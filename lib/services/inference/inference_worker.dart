import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'inference_protocol.dart';

class InferenceWorker {
  InferenceWorker._(this._process) {
    _stdoutSubscription = _process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_handleLine, onDone: _handleExit);
    _stderrSubscription = _process.stderr.transform(utf8.decoder).listen((message) => _diagnostics.add(message));
    _process.exitCode.then((_) => _handleExit());
  }

  final Process _process;
  final _pending = <String, Completer<InferenceResponse>>{};
  final _diagnostics = StreamController<String>.broadcast();
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  bool _closed = false;

  Stream<String> get diagnostics => _diagnostics.stream;

  static Future<InferenceWorker> start(String executable, List<String> args, {String? workingDirectory}) async {
    var resolvedExecutable = executable;
    var resolvedWorkingDirectory = workingDirectory;
    if (Platform.isWindows) {
      final bundledDirectory = p.join(p.dirname(Platform.resolvedExecutable), 'inference_runtime');
      final bundledPython = p.join(bundledDirectory, 'python.exe');
      if (await File(bundledPython).exists()) {
        resolvedExecutable = bundledPython;
        resolvedWorkingDirectory = bundledDirectory;
      }
    }
    final process = await Process.start(resolvedExecutable, args, runInShell: false, workingDirectory: resolvedWorkingDirectory);
    return InferenceWorker._(process);
  }

  Future<InferenceResponse> request(Map<String, Object?> payload) {
    if (_closed) throw const InferenceException('worker_closed', 'Inference worker is closed.');
    final requestId = const Uuid().v4();
    final completer = Completer<InferenceResponse>();
    _pending[requestId] = completer;
    _process.stdin.writeln(jsonEncode({'protocol': 1, 'request_id': requestId, ...payload}));
    return completer.future;
  }

  void _handleLine(String line) {
    try {
      final raw = jsonDecode(line);
      if (raw is! Map) throw const FormatException('Worker response must be a JSON object.');
      final map = Map<String, Object?>.from(raw);
      final requestId = map['request_id'] as String?;
      if (requestId == null) throw const FormatException('Worker response has no request_id.');
      final completer = _pending.remove(requestId);
      if (completer == null) return;
      try { completer.complete(decodeInferenceResponse(map)); } catch (error, stack) { completer.completeError(error, stack); }
    } catch (error, stack) {
      _failAll(InferenceException('invalid_worker_output', '$error'), stack);
    }
  }

  void _handleExit() {
    if (_closed) return;
    _closed = true;
    _failAll(const InferenceException('worker_exited', 'Inference worker exited unexpectedly.'), StackTrace.current);
  }

  void _failAll(Object error, StackTrace stack) {
    final pending = _pending.values.toList();
    _pending.clear();
    for (final completer in pending) { if (!completer.isCompleted) completer.completeError(error, stack); }
  }

  Future<void> dispose() async {
    if (_closed) return;
    try { await request({'action': 'shutdown'}).timeout(const Duration(seconds: 2)); } catch (_) { _process.kill(); }
    _closed = true;
    await _process.stdin.close();
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    await _diagnostics.close();
    _failAll(const InferenceException('cancelled', 'Inference worker was disposed.'), StackTrace.current);
  }
}
