import 'dart:io';

import 'package:path_provider/path_provider.dart';

const bool isWebPlatform = false;

Future<String> defaultStorageDirectory() async {
  final supportDir = await getApplicationSupportDirectory();
  return '${supportDir.path}${Platform.pathSeparator}KittenTTS';
}
