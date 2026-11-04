import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yumyum_backend/features/account/domain/photo_storage.dart';

/// [PhotoStorage] on the local filesystem, under [directory].
class LocalPhotoStorage implements PhotoStorage {
  /// Constructs a [LocalPhotoStorage] rooted at [directory].
  const LocalPhotoStorage(this.directory);

  /// Reads `UPLOADS_DIR` (default `uploads`) and stores photos in its
  /// `avatars/` subdirectory.
  factory LocalPhotoStorage.fromEnvironment() => LocalPhotoStorage(
        p.join(Platform.environment['UPLOADS_DIR'] ?? 'uploads', 'avatars'),
      );

  /// The directory photos are stored in.
  final String directory;

  // basename() strips any directory part, so a stored name can never reach
  // outside [directory] (e.g. "../../etc/passwd").
  File _file(String name) => File(p.join(directory, p.basename(name)));

  @override
  Future<void> write(String name, List<int> bytes) async {
    await Directory(directory).create(recursive: true);
    await _file(name).writeAsBytes(bytes);
  }

  @override
  Future<StoredFile?> read(String name) async {
    final file = _file(name);
    if (!file.existsSync()) return null;
    return StoredFile(
      content: file.openRead,
      lastModified: file.lastModifiedSync(),
    );
  }

  @override
  Future<void> delete(String name) async {
    final file = _file(name);
    if (file.existsSync()) await file.delete();
  }
}
