import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../kitten_model.dart';
import '../kitten_tts_config.dart';
import '../kitten_tts_error.dart';

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
  final dir = _resolveDir(model, storageDir);
  final onnxPath = p.join(dir, onnxFileName(model));
  final voicesPath = p.join(dir, voicesFileName(model));
  return ModelCacheInfo(
    model: model,
    directory: dir,
    onnxPath: onnxPath,
    voicesPath: voicesPath,
    onnxExists: await File(onnxPath).exists(),
    voicesExists: await File(voicesPath).exists(),
  );
}

Future<ModelCacheInfo> getProvidedModelCacheInfo(
  KittenTTSModelId model,
  KittenTTSModelFiles files,
) async {
  return ModelCacheInfo(
    model: model,
    directory: p.dirname(files.onnxPath) == p.dirname(files.voicesPath)
        ? p.dirname(files.onnxPath)
        : '',
    onnxPath: _stripFileScheme(files.onnxPath),
    voicesPath: _stripFileScheme(files.voicesPath),
    onnxExists: await File(_stripFileScheme(files.onnxPath)).exists(),
    voicesExists: await File(_stripFileScheme(files.voicesPath)).exists(),
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
  if (modelFiles != null) {
    progressHandler?.call(
      0,
      const DownloadProgressInfo(
        stage: DownloadProgressStage.checkingCache,
        cached: false,
      ),
    );
    final info = await getProvidedModelCacheInfo(model, modelFiles);
    if (!info.onnxExists) throw KittenTTSError.modelFileNotFound(info.onnxPath);
    if (!info.voicesExists) {
      throw KittenTTSError.voicesFileNotFound(info.voicesPath);
    }
    progressHandler?.call(
      1,
      const DownloadProgressInfo(
        stage: DownloadProgressStage.cached,
        cached: true,
      ),
    );
    return ModelPaths(onnxPath: info.onnxPath, voicesPath: info.voicesPath);
  }

  return downloadModelIfNeeded(
    model,
    storageDir,
    progressHandler,
    force: force,
    retries: retries,
    baseUrl: baseUrl,
  );
}

Future<ModelPaths> downloadModelIfNeeded(
  KittenTTSModelId model,
  String storageDir,
  ProgressHandler? progressHandler, {
  bool force = false,
  int retries = 4,
  String? baseUrl,
}) async {
  final dir = _resolveDir(model, storageDir);
  final onnxPath = p.join(dir, onnxFileName(model));
  final voicesPath = p.join(dir, voicesFileName(model));

  if (force) {
    await Future.wait([
      _deleteIfExists(onnxPath),
      _deleteIfExists(voicesPath),
      _deleteIfExists('$onnxPath.download'),
      _deleteIfExists('$voicesPath.download'),
    ]);
  }

  progressHandler?.call(
    0,
    const DownloadProgressInfo(
      stage: DownloadProgressStage.checkingCache,
      cached: false,
    ),
  );
  final onnxExists = await File(onnxPath).exists();
  final voicesExists = await File(voicesPath).exists();
  if (onnxExists && voicesExists) {
    progressHandler?.call(
      1,
      const DownloadProgressInfo(
        stage: DownloadProgressStage.cached,
        cached: true,
      ),
    );
    return ModelPaths(onnxPath: onnxPath, voicesPath: voicesPath);
  }

  await Directory(dir).create(recursive: true);
  final urlBase =
      baseUrl?.isNotEmpty == true ? baseUrl! : huggingFaceBaseUrl(model);
  final aggregate = _AggregateProgress(progressHandler);
  final downloads = <Future<void>>[];

  if (!onnxExists) {
    downloads.add(
      _downloadFile(
        '$urlBase/${onnxFileName(model)}',
        onnxPath,
        DownloadProgressAsset.model,
        retries,
        aggregate.call,
      ),
    );
  }
  if (!voicesExists) {
    downloads.add(
      _downloadFile(
        '$urlBase/${voicesFileName(model)}',
        voicesPath,
        DownloadProgressAsset.voices,
        retries,
        aggregate.call,
      ),
    );
  }

  await Future.wait(downloads);
  progressHandler?.call(
    1,
    const DownloadProgressInfo(
        stage: DownloadProgressStage.complete, cached: false),
  );
  return ModelPaths(onnxPath: onnxPath, voicesPath: voicesPath);
}

Future<void> clearModelCache(KittenTTSModelId model, String storageDir) async {
  final info = await getModelCacheInfo(model, storageDir);
  await Future.wait([
    _deleteIfExists(info.onnxPath),
    _deleteIfExists(info.voicesPath),
    _deleteIfExists('${info.onnxPath}.download'),
    _deleteIfExists('${info.voicesPath}.download'),
  ]);
}

String _resolveDir(KittenTTSModelId model, String storageDir) =>
    p.join(storageDir, validateModel(model));

String _stripFileScheme(String path) =>
    path.startsWith('file://') ? path.substring('file://'.length) : path;

Future<void> _downloadFile(
  String url,
  String path,
  DownloadProgressAsset asset,
  int retries,
  ProgressHandler? progressHandler,
) async {
  Object? lastError;
  for (var attempt = 1; attempt <= retries; attempt += 1) {
    try {
      await _downloadFileOnce(
          url, path, asset, attempt, retries, progressHandler);
      return;
    } catch (error) {
      lastError = error;
      if (attempt == retries) break;
      progressHandler?.call(
        0,
        DownloadProgressInfo(
          stage: DownloadProgressStage.retrying,
          asset: asset,
          attempt: attempt + 1,
          totalAttempts: retries,
          message: errorMessage(error),
        ),
      );
      await Future<void>.delayed(Duration(milliseconds: 750 * attempt));
    }
  }
  throw KittenTTSError.downloadFailed(
    'Failed after $retries attempts: ${errorMessage(lastError)}',
    lastError,
  );
}

Future<void> _downloadFileOnce(
  String url,
  String path,
  DownloadProgressAsset asset,
  int attempt,
  int totalAttempts,
  ProgressHandler? progressHandler,
) async {
  final tempPath = '$path.download';
  progressHandler?.call(
    0,
    DownloadProgressInfo(
      stage: DownloadProgressStage.downloading,
      asset: asset,
      attempt: attempt,
      totalAttempts: totalAttempts,
    ),
  );
  await _deleteIfExists(tempPath);

  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(url));
    final response =
        await client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw KittenTTSError.downloadFailed(
          'HTTP ${response.statusCode} downloading $url');
    }
    final contentLength = response.contentLength ?? 0;
    var bytesWritten = 0;
    final sink = File(tempPath).openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      bytesWritten += chunk.length;
      if (contentLength > 0) {
        progressHandler?.call(
          bytesWritten / contentLength,
          DownloadProgressInfo(
            stage: DownloadProgressStage.downloading,
            asset: asset,
            attempt: attempt,
            totalAttempts: totalAttempts,
            bytesWritten: bytesWritten,
            contentLength: contentLength,
          ),
        );
      }
    }
    await sink.flush();
    await sink.close();
    await File(tempPath).rename(path);
    progressHandler?.call(
      1,
      DownloadProgressInfo(
        stage: DownloadProgressStage.complete,
        asset: asset,
        attempt: attempt,
        totalAttempts: totalAttempts,
      ),
    );
  } catch (error) {
    await _deleteIfExists(tempPath);
    if (error is KittenTTSError) rethrow;
    throw KittenTTSError.downloadFailed(errorMessage(error), error);
  } finally {
    client.close();
  }
}

Future<void> _deleteIfExists(String path) async {
  try {
    await File(path).delete();
  } catch (_) {
    // Missing temp/cache files are fine during conservative cleanup.
  }
}

class _AggregateProgress {
  _AggregateProgress(this._handler);

  final ProgressHandler? _handler;
  final _files =
      <DownloadProgressAsset, ({int bytesWritten, int contentLength})>{};

  void call(double progress, [DownloadProgressInfo? info]) {
    final asset = info?.asset;
    if (asset != null && (info?.contentLength ?? 0) > 0) {
      _files[asset] = (
        bytesWritten: (info?.bytesWritten ?? 0).clamp(0, info!.contentLength!),
        contentLength: info.contentLength!,
      );
    } else if (asset != null &&
        info?.stage == DownloadProgressStage.complete &&
        !_files.containsKey(asset)) {
      _files[asset] = (bytesWritten: 1, contentLength: 1);
    }

    final totalBytes = _files.values.fold<int>(
      0,
      (sum, file) => sum + file.contentLength,
    );
    final writtenBytes = _files.values.fold<int>(
      0,
      (sum, file) => sum + file.bytesWritten,
    );
    final aggregate =
        totalBytes > 0 ? (writtenBytes / totalBytes).clamp(0.0, 1.0) : progress;
    _handler?.call(aggregate, info);
  }
}
