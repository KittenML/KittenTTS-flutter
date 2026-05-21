import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../kitten_tts_error.dart';

class DictionaryPaths {
  const DictionaryPaths(this.rulesPath, this.listPath);

  final String rulesPath;
  final String listPath;
}

Future<DictionaryPaths> resolveDictionaryPaths({
  required String storageDirectory,
  required String rulesUrl,
  required String listUrl,
  required String? rulesPath,
  required String? listPath,
  required String? rulesText,
  required String? listText,
  required void Function(double progress)? onProgress,
}) async {
  _assertNoPartialData(
    rulesPath: rulesPath,
    listPath: listPath,
    rulesText: rulesText,
    listText: listText,
  );

  final base = storageDirectory.isEmpty
      ? p.join(Directory.systemTemp.path, 'KittenTTS')
      : storageDirectory;
  final dir = Directory(p.join(base, 'CEPhonemizer'));
  await dir.create(recursive: true);

  final resolvedRulesPath = p.join(dir.path, 'en_rules');
  final resolvedListPath = p.join(dir.path, 'en_list');

  if (rulesText != null && listText != null) {
    await File(resolvedRulesPath).writeAsString(rulesText);
    await File(resolvedListPath).writeAsString(listText);
    onProgress?.call(1);
    return DictionaryPaths(resolvedRulesPath, resolvedListPath);
  }

  if (rulesPath != null && listPath != null) {
    onProgress?.call(1);
    return DictionaryPaths(
        _stripFileScheme(rulesPath), _stripFileScheme(listPath));
  }

  final rulesFile = File(resolvedRulesPath);
  final listFile = File(resolvedListPath);
  final rulesExists = await rulesFile.exists();
  final listExists = await listFile.exists();
  if (rulesExists && listExists) {
    onProgress?.call(1);
    return DictionaryPaths(resolvedRulesPath, resolvedListPath);
  }

  await Future.wait([
    if (!rulesExists)
      _downloadTextFile(
        rulesUrl,
        resolvedRulesPath,
        (progress) => onProgress?.call(progress * 0.5),
      ),
    if (!listExists)
      _downloadTextFile(
        listUrl,
        resolvedListPath,
        (progress) => onProgress?.call(0.5 + progress * 0.5),
      ),
  ]);
  onProgress?.call(1);
  return DictionaryPaths(resolvedRulesPath, resolvedListPath);
}

void _assertNoPartialData({
  required String? rulesPath,
  required String? listPath,
  required String? rulesText,
  required String? listText,
}) {
  if ((rulesText == null) != (listText == null)) {
    throw KittenTTSError.phonemizerFailed(
      'Both rulesText and listText must be provided for bundled CEPhonemizer data.',
    );
  }
  if ((rulesPath == null) != (listPath == null)) {
    throw KittenTTSError.phonemizerFailed(
      'Both rulesPath and listPath must be provided for bundled CEPhonemizer data.',
    );
  }
}

Future<void> _downloadTextFile(
  String url,
  String targetPath,
  void Function(double progress)? onProgress,
) async {
  final tempPath = '$targetPath.download';
  final client = http.Client();
  try {
    final response = await client.send(http.Request('GET', Uri.parse(url)));
    if (response.statusCode != 200) {
      throw KittenTTSError.phonemizerFailed(
        'HTTP ${response.statusCode} downloading $url',
      );
    }
    final contentLength = response.contentLength ?? 0;
    var written = 0;
    final sink = File(tempPath).openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      written += chunk.length;
      if (contentLength > 0) onProgress?.call(written / contentLength);
    }
    await sink.flush();
    await sink.close();
    await File(tempPath).rename(targetPath);
  } catch (error) {
    try {
      await File(tempPath).delete();
    } catch (_) {
      // Missing temp files are fine during retry cleanup.
    }
    if (error is KittenTTSError) rethrow;
    throw KittenTTSError.phonemizerFailed(errorMessage(error), error);
  } finally {
    client.close();
  }
}

String _stripFileScheme(String path) =>
    path.startsWith('file://') ? path.substring('file://'.length) : path;
