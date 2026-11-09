/// A stored photo file, ready to stream.
class StoredFile {
  /// Constructs a [StoredFile].
  const StoredFile({required this.content, required this.lastModified});

  /// Opens the file's bytes. A function so each read gets a fresh stream.
  final Stream<List<int>> Function() content;

  /// When the file was last written, for cache validation.
  final DateTime lastModified;
}

/// Where profile photo bytes live.
///
/// A port: the account use cases decide names and rules; whether the bytes
/// end up on local disk or in object storage is an infrastructure detail.
abstract interface class PhotoStorage {
  /// Stores [bytes] under [name], replacing anything already there.
  Future<void> write(String name, List<int> bytes);

  /// The file stored under [name], or null when there is none.
  Future<StoredFile?> read(String name);

  /// Removes the file stored under [name]; a no-op when there is none.
  Future<void> delete(String name);
}
