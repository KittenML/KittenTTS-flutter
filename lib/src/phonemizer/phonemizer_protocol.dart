abstract interface class KittenPhonemizerProtocol {
  Future<void> downloadIfNeeded(
    String storageDirectory, {
    void Function(double progress)? onProgress,
  }) async {}

  Future<String> phonemize(String text);

  Future<void> dispose() async {}
}
