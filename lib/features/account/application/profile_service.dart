import 'package:yumyum_backend/features/account/domain/photo_storage.dart';
import 'package:yumyum_backend/features/account/domain/user.dart';
import 'package:yumyum_backend/features/account/domain/user_repository.dart';

/// The outcome of looking up a profile photo.
sealed class PhotoLookup {
  const PhotoLookup();
}

/// The photo exists and can be streamed.
class PhotoFound extends PhotoLookup {
  /// Constructs a [PhotoFound].
  const PhotoFound(this.file, this.mimeType);

  /// The stored file.
  final StoredFile file;

  /// The photo's MIME type, derived from its stored extension.
  final String mimeType;
}

/// The user has never uploaded a photo.
class NoPhoto extends PhotoLookup {
  /// Constructs a [NoPhoto].
  const NoPhoto();
}

/// A photo is recorded for the user but its file is gone or unreadable.
class PhotoMissing extends PhotoLookup {
  /// Constructs a [PhotoMissing].
  const PhotoMissing();
}

/// The outcome of uploading a profile photo.
sealed class PhotoUpload {
  const PhotoUpload();
}

/// The photo was stored and is now the user's profile photo.
class PhotoUploaded extends PhotoUpload {
  /// Constructs a [PhotoUploaded].
  const PhotoUploaded();
}

/// The photo is not one of the accepted image types.
class PhotoTypeNotAllowed extends PhotoUpload {
  /// Constructs a [PhotoTypeNotAllowed].
  const PhotoTypeNotAllowed();
}

/// The photo is larger than [ProfileService.maxPhotoBytes].
class PhotoTooLarge extends PhotoUpload {
  /// Constructs a [PhotoTooLarge].
  const PhotoTooLarge();
}

/// Reads and edits the signed-in user's profile and profile photo.
class ProfileService {
  /// Constructs a [ProfileService].
  ProfileService({
    required UserRepository users,
    required PhotoStorage photos,
    DateTime Function() now = DateTime.now,
  })  : _users = users,
        _photos = photos,
        _now = now;

  final UserRepository _users;
  final PhotoStorage _photos;
  final DateTime Function() _now;

  /// The largest accepted photo, in bytes.
  static const maxPhotoBytes = 5 * 1024 * 1024;

  static const _extensionByMime = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  /// The profile of [uid], or null when no such user exists.
  Future<User?> find(String uid) => _users.findByUid(uid);

  /// Updates [uid]'s profile and returns it, or returns null when no such
  /// user exists.
  ///
  /// [fullName] is split on whitespace: the first word becomes the first
  /// name and the rest the last name. A null or blank [email] leaves the
  /// stored address unchanged.
  Future<User?> update(String uid, {String? fullName, String? email}) {
    final words = fullName?.trim().split(RegExp(r'\s+')) ?? const <String>[];
    final hasName = words.isNotEmpty && words.first.isNotEmpty;
    final trimmedEmail = email?.trim();
    return _users.updateProfile(
      uid: uid,
      firstName: hasName ? words.first : null,
      lastName: hasName ? words.skip(1).join(' ') : null,
      email: trimmedEmail == null || trimmedEmail.isEmpty ? null : trimmedEmail,
    );
  }

  /// Looks up [uid]'s profile photo.
  Future<PhotoLookup> photo(String uid) async {
    final name = await _users.getPhotoUri(uid: uid);
    if (name == null || name.isEmpty) return const NoPhoto();

    final mimeType = _mimeFor(name);
    final file = await _photos.read(name);
    if (mimeType == null || file == null) return const PhotoMissing();
    return PhotoFound(file, mimeType);
  }

  /// Stores [bytes] as [uid]'s new profile photo and removes the old one.
  Future<PhotoUpload> uploadPhoto(
    String uid, {
    required List<int> bytes,
    required String mimeType,
  }) async {
    final extension = _extensionByMime[mimeType];
    if (extension == null) return const PhotoTypeNotAllowed();
    if (bytes.length > maxPhotoBytes) return const PhotoTooLarge();

    final name = '$uid-${_now().millisecondsSinceEpoch}.$extension';
    await _photos.write(name, bytes);

    // Point the profile at the new file before removing the old one, so a
    // failure in between leaves an orphaned file rather than a broken link.
    final previous = await _users.getPhotoUri(uid: uid);
    await _users.updatePhotoUri(uid: uid, photoUrl: name);
    if (previous != null && previous.isNotEmpty && previous != name) {
      await _photos.delete(previous);
    }
    return const PhotoUploaded();
  }

  static String? _mimeFor(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    final extension = name.substring(dot + 1).toLowerCase();
    for (final entry in _extensionByMime.entries) {
      if (entry.value == extension) return entry.key;
    }
    return null;
  }
}
