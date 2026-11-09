import 'package:test/test.dart';
import 'package:yumyum_backend/features/account/application/profile_service.dart';
import 'package:yumyum_backend/features/account/domain/user.dart';

import '../../../helpers/fakes.dart';

/// A [StubUserRepository] that records profile and photo writes.
class _RecordingUsers extends StubUserRepository {
  _RecordingUsers(super.user);

  Map<String, String?>? profileUpdate;
  String? photoName;

  @override
  Future<User?> updateProfile({
    required String uid,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    profileUpdate = {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
    };
    return user;
  }

  @override
  Future<String?> getPhotoUri({required String uid}) async => photoName;

  @override
  Future<void> updatePhotoUri({
    required String uid,
    required String photoUrl,
  }) async {
    photoName = photoUrl;
  }
}

void main() {
  const user = User(
    uid: 'user-1',
    firstName: 'Ada',
    lastName: 'Lovelace',
    email: 'ada@example.com',
  );

  late _RecordingUsers users;
  late InMemoryPhotoStorage photos;
  late ProfileService service;

  setUp(() {
    users = _RecordingUsers(user);
    photos = InMemoryPhotoStorage();
    service = ProfileService(
      users: users,
      photos: photos,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
  });

  group('update', () {
    test('keeps every word after the first in the last name', () async {
      await service.update('user-1', fullName: '  Ada King  Lovelace ');

      expect(users.profileUpdate!['firstName'], equals('Ada'));
      expect(users.profileUpdate!['lastName'], equals('King Lovelace'));
    });

    // The route used to send '' for a missing email, which overwrote the
    // stored address with an empty string.
    test('leaves the email alone when it is missing or blank', () async {
      await service.update('user-1', fullName: 'Ada');
      expect(users.profileUpdate!['email'], isNull);

      await service.update('user-1', email: '   ');
      expect(users.profileUpdate!['email'], isNull);
    });

    test('leaves the name alone when no full name is given', () async {
      await service.update('user-1', email: 'new@example.com');

      expect(users.profileUpdate!['firstName'], isNull);
      expect(users.profileUpdate!['lastName'], isNull);
      expect(users.profileUpdate!['email'], equals('new@example.com'));
    });
  });

  group('uploadPhoto', () {
    test('stores the photo and replaces the previous one', () async {
      users.photoName = 'user-1-1.png';
      photos.files['user-1-1.png'] = [1];

      final result = await service.uploadPhoto(
        'user-1',
        bytes: [1, 2, 3],
        mimeType: 'image/jpeg',
      );

      expect(result, isA<PhotoUploaded>());
      expect(users.photoName, equals('user-1-1000.jpg'));
      expect(photos.files.keys, equals(['user-1-1000.jpg']));
    });

    test('rejects a type that is not jpeg, png or webp', () async {
      final result = await service.uploadPhoto(
        'user-1',
        bytes: [1],
        mimeType: 'image/gif',
      );

      expect(result, isA<PhotoTypeNotAllowed>());
      expect(photos.files, isEmpty);
    });

    test('rejects a photo over the size limit', () async {
      final result = await service.uploadPhoto(
        'user-1',
        bytes: List.filled(ProfileService.maxPhotoBytes + 1, 0),
        mimeType: 'image/png',
      );

      expect(result, isA<PhotoTooLarge>());
      expect(photos.files, isEmpty);
    });
  });

  group('photo', () {
    test('reports no photo when none was uploaded', () async {
      expect(await service.photo('user-1'), isA<NoPhoto>());
    });

    test('reports a missing file when the record points nowhere', () async {
      users.photoName = 'user-1-1.png';

      expect(await service.photo('user-1'), isA<PhotoMissing>());
    });

    test('derives the MIME type from the stored extension', () async {
      users.photoName = 'user-1-1.webp';
      photos.files['user-1-1.webp'] = [1];

      final lookup = await service.photo('user-1');

      expect(
        lookup,
        isA<PhotoFound>().having((f) => f.mimeType, 'mime', 'image/webp'),
      );
    });
  });
}
