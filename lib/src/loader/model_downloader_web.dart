import 'package:path/path.dart' as p;

import '../kitten_model.dart';
import '../kitten_tts_config.dart';

enum DownloadProgressStage {
  checkingCache,
  cached,
  downloading,
  retrying,
  complete,
}

enum DownloadProgressAsset {
  model,
  voices,
  phonemizerRules,
  phonemizerList,
}

class DownloadProgressInfo {
  const DownloadProgressInfo({
    required this.stage,
    this.asset,
    this.cached,
    this.attempt,
    this.totalAttempts,
    this.bytesWritten,
    this.contentLength,
    this.message,
  });

  final DownloadProgressStage stage;
  final DownloadProgressAsset? asset;
  final bool? cached;
  final int? attempt;
  final int? totalAttempts;
  final int? bytesWritten;
  final int? contentLength;
  final String? message;
}

typedef ProgressHandler = void Function(
  double progress, [
  DownloadProgressInfo? info,
]);

class ModelPaths {
  const ModelPaths({required this.onnxPath, required this.voicesPath});

  final String onnxPath;
  final String voicesPath;
}

class ModelCacheInfo {
  const ModelCacheInfo({
    required this.model,
    required this.directory,
    required this.onnxPath,
    required this.voicesPath,
    required this.onnxExists,
    required this.voicesExists,
  });

  final KittenTTSModelId model;
  final String directory;
  final String onnxPath;
  final String voicesPath;
  final bool onnxExists;
  final bool voicesExists;

  bool get isCached => onnxExists && voicesExists;
}

Future<bool> isModelCached(KittenTTSModelId model, String storageDir) async =>
    (await getModelCacheInfo(model, storageDir)).isCached;

Future<ModelCacheInfo> getModelCacheInfo(
  KittenTTSModelId model,
  String storageDir,
) async {
  final paths = _webModelPaths(model, storageDir);
  return ModelCacheInfo(
    model: model,
    directory: _resolveDir(model, storageDir),
    onnxPath: paths.onnxPath,
    voicesPath: paths.voicesPath,
    onnxExists: false,
    voicesExists: false,
  );
}

Future<ModelCacheInfo> getProvidedModelCacheInfo(
  KittenTTSModelId model,
  KittenTTSModelFiles files,
) async {
  final onnxPath = _stripFileScheme(files.onnxPath);
  final voicesPath = _stripFileScheme(files.voicesPath);
  return ModelCacheInfo(
    model: model,
    directory:
        p.dirname(onnxPath) == p.dirname(voicesPath) ? p.dirname(onnxPath) : '',
    onnxPath: onnxPath,
    voicesPath: voicesPath,
    onnxExists: true,
    voicesExists: true,
  );
}

Future<ModelPaths> resolveModelPaths(
  KittenTTSModelId model,
  String storageDir,
  ProgressHandler? progressHandler, {
  KittenTTSModelFiles? modelFiles,
  bool force = false,
  int retries = 4,
  String? baseUrl,
}) async {
  progressHandler?.call(
    0,
    const DownloadProgressInfo(
      stage: DownloadProgressStage.checkingCache,
      cached: false,
    ),
  );

  if (modelFiles != null) {
    final info = await getProvidedModelCacheInfo(model, modelFiles);
    progressHandler?.call(
      1,
      const DownloadProgressInfo(
        stage: DownloadProgressStage.cached,
        cached: true,
      ),
    );
    return ModelPaths(onnxPath: info.onnxPath, voicesPath: info.voicesPath);
  }

  final paths = _webModelPaths(model, storageDir, baseUrl: baseUrl);
  progressHandler?.call(
    1,
    const DownloadProgressInfo(
      stage: DownloadProgressStage.complete,
      cached: false,
    ),
  );
  return paths;
}

Future<ModelPaths> downloadModelIfNeeded(
  KittenTTSModelId model,
  String storageDir,
  ProgressHandler? progressHandler, {
  bool force = false,
  int retries = 4,
  String? baseUrl,
}) =>
    resolveModelPaths(
      model,
      storageDir,
      progressHandler,
      force: force,
      retries: retries,
      baseUrl: baseUrl,
    );

Future<void> clearModelCache(KittenTTSModelId model, String storageDir) async {}

String _resolveDir(KittenTTSModelId model, String storageDir) {
  final base = storageDir.isEmpty ? 'KittenTTS' : storageDir;
  return '$base/${validateModel(model)}';
}

ModelPaths _webModelPaths(
  KittenTTSModelId model,
  String storageDir, {
  String? baseUrl,
}) {
  final urlBase =
      baseUrl?.isNotEmpty == true ? baseUrl! : huggingFaceBaseUrl(model);
  return ModelPaths(
    onnxPath: '$urlBase/${onnxFileName(model)}',
    voicesPath: '$urlBase/${voicesFileName(model)}',
  );
}

String _stripFileScheme(String path) =>
    path.startsWith('file://') ? path.substring('file://'.length) : path;
