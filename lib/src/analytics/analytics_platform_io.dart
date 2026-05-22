import 'dart:io';

Future<String?> readAnonymousId(String key, String? path) async {
  if (path == null) return null;
  try {
    final value = (await File(path).readAsString()).trim();
    return _isUuid(value) ? value : null;
  } catch (_) {
    return null;
  }
}

Future<void> writeAnonymousId(String key, String? path, String value) async {
  if (path == null) return;
  try {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(value);
  } catch (_) {
    // Analytics identifiers are best-effort only.
  }
}

String currentPlatform() {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}

String runtimeVersion() {
  final version = Platform.version.split(' ').first.split('.');
  final majorMinor = version.take(2).join('.');
  return majorMinor.isEmpty ? 'flutter unknown' : 'flutter dart $majorMinor';
}

Map<String, String> analyticsHeaders(String sdkVersion) => {
      'User-Agent': 'KittenTTS-Flutter/${_sanitizeHeaderValue(sdkVersion)}',
    };

bool _isUuid(String value) => RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);

String _sanitizeHeaderValue(String value) =>
    value.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
