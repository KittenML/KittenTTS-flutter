import '../kitten_tts_error.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class DictionaryPaths {
  const DictionaryPaths(this.rulesPath, this.listPath);

  final String rulesPath;
  final String listPath;
}

const _virtualRulesPath = '/cephonemizer/en_rules';
const _virtualListPath = '/cephonemizer/en_list';
final _dictionaryTextByPath = <String, String>{};

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

  if (rulesText != null && listText != null) {
    _dictionaryTextByPath[_virtualRulesPath] = rulesText;
    _dictionaryTextByPath[_virtualListPath] = listText;
    onProgress?.call(1);
    return const DictionaryPaths(_virtualRulesPath, _virtualListPath);
  }

  if (rulesPath != null && listPath != null) {
    final rules = await _readText(rulesPath);
    final list = await _readText(listPath);
    _dictionaryTextByPath[_virtualRulesPath] = rules;
    _dictionaryTextByPath[_virtualListPath] = list;
    onProgress?.call(1);
    return const DictionaryPaths(_virtualRulesPath, _virtualListPath);
  }

  final rules = await _downloadText(rulesUrl);
  onProgress?.call(0.5);
  final list = await _downloadText(listUrl);
  _dictionaryTextByPath[_virtualRulesPath] = rules;
  _dictionaryTextByPath[_virtualListPath] = list;
  onProgress?.call(1);
  return const DictionaryPaths(_virtualRulesPath, _virtualListPath);
}

String dictionaryTextForPath(String path) {
  final text = _dictionaryTextByPath[path];
  if (text == null) {
    throw KittenTTSError.phonemizerFailed(
      'CEPhonemizer dictionary data was not loaded for $path.',
    );
  }
  return text;
}

Future<String> _readText(String source) async {
  final uri = Uri.tryParse(source);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return _downloadText(source);
  }
  final assetKey = source.startsWith('asset://')
      ? source.substring('asset://'.length)
      : source;
  try {
    return rootBundle.loadString(assetKey);
  } catch (error) {
    throw KittenTTSError.phonemizerFailed(
      'Could not load CEPhonemizer asset $source: ${errorMessage(error)}',
      error,
    );
  }
}

Future<String> _downloadText(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KittenTTSError.phonemizerFailed(
        'HTTP ${response.statusCode} downloading $url',
      );
    }
    return response.body;
  } catch (error) {
    if (error is KittenTTSError) rethrow;
    throw KittenTTSError.phonemizerFailed(errorMessage(error), error);
  }
}
