import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WhisperModelService {
  static const String _modelUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin';
  static const String _modelFileName = 'ggml-tiny.en.bin';

  Future<Directory> get _modelsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'models'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> get _modelFile async {
    final dir = await _modelsDir;
    return File(p.join(dir.path, _modelFileName));
  }

  Future<bool> get isDownloaded async => (await _modelFile).existsSync();

  /// Returns the local file path, downloading if necessary.
  /// [onProgress] receives values in [0, 1].
  Future<String> ensureModel({void Function(double progress)? onProgress}) async {
    final file = await _modelFile;
    if (file.existsSync()) return file.path;

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(_modelUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Whisper model download failed: HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      int received = 0;

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call(received / total);
        }
      }
      await sink.close();
      return file.path;
    } catch (e) {
      // Clean up partial file on failure
      if (file.existsSync()) file.deleteSync();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> deleteModel() async {
    final file = await _modelFile;
    if (file.existsSync()) file.deleteSync();
  }
}
