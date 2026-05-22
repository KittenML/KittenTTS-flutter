import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('globalThis')
external JSObject get _globalThis;

Future<String?> readAnonymousId(String key, String? path) async {
  try {
    final storageValue = _globalThis.getProperty('localStorage'.toJS);
    if (storageValue.isUndefinedOrNull) return null;
    final storage = storageValue as JSObject;
    final value = storage.callMethod('getItem'.toJS, key.toJS);
    if (value.isUndefinedOrNull) return null;
    final id = (value as JSString).toDart.trim();
    return _isUuid(id) ? id : null;
  } catch (_) {
    return null;
  }
}

Future<void> writeAnonymousId(String key, String? path, String value) async {
  try {
    final storageValue = _globalThis.getProperty('localStorage'.toJS);
    if (storageValue.isUndefinedOrNull) return;
    final storage = storageValue as JSObject;
    storage.callMethod('setItem'.toJS, key.toJS, value.toJS);
  } catch (_) {
    // Browser storage can be unavailable in private contexts.
  }
}

String currentPlatform() {
  final userAgent = _userAgent();
  if (RegExp('iphone|ipad|ipod', caseSensitive: false).hasMatch(userAgent)) {
    return 'ios';
  }
  if (RegExp('android', caseSensitive: false).hasMatch(userAgent)) {
    return 'android';
  }
  if (RegExp('mac os x|macintosh', caseSensitive: false).hasMatch(userAgent)) {
    return 'macos';
  }
  if (RegExp('windows', caseSensitive: false).hasMatch(userAgent)) {
    return 'windows';
  }
  if (RegExp('linux', caseSensitive: false).hasMatch(userAgent)) {
    return 'linux';
  }
  return 'unknown';
}

String runtimeVersion() {
  final browser = _browserVersion(_userAgent());
  return browser == null ? 'flutter web' : 'flutter web $browser';
}

Map<String, String> analyticsHeaders(String sdkVersion) => const {};

String _userAgent() {
  try {
    final navigatorValue = _globalThis.getProperty('navigator'.toJS);
    if (navigatorValue.isUndefinedOrNull) return '';
    final userAgentValue =
        (navigatorValue as JSObject).getProperty('userAgent'.toJS);
    if (userAgentValue.isUndefinedOrNull) return '';
    return (userAgentValue as JSString).toDart;
  } catch (_) {
    return '';
  }
}

String? _browserVersion(String userAgent) {
  final edge = RegExp(r'\bEdg/(\d+)').firstMatch(userAgent);
  if (edge != null) return 'edge ${edge.group(1)}';
  final chrome = RegExp(r'\b(?:Chrome|CriOS)/(\d+)').firstMatch(userAgent);
  if (chrome != null) return 'chrome ${chrome.group(1)}';
  final firefox = RegExp(r'\bFirefox/(\d+)').firstMatch(userAgent);
  if (firefox != null) return 'firefox ${firefox.group(1)}';
  final safari = RegExp(r'\bVersion/(\d+).*\bSafari/').firstMatch(userAgent);
  if (safari != null) return 'safari ${safari.group(1)}';
  return null;
}

bool _isUuid(String value) => RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
