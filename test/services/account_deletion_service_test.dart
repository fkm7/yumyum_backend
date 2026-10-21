import 'package:test/test.dart';
import 'package:yumyum_backend/models/credential.dart';
import 'package:yumyum_backend/services/account_deletion_service.dart';
import 'package:yumyum_backend/services/credential_service.dart';

import '../helpers/fakes.dart';
import '../helpers/test_context.dart';

/// A [StubUserRepository] that records which uid was deleted.
class _RecordingUserRepository extends StubUserRepository {
  String? deletedUid;

  @override
  Future<void> delete(String uid) async => deletedUid = uid;
}

void main() {
  late _RecordingUserRepository users;

  AccountDeletionService service({Credential? stored}) {
    users = _RecordingUserRepository();
    return AccountDeletionService(
      users: users,
      credentials: CredentialService(
        credentials: StubCredentialRepository(stored),
        hasher: testHasher,
      ),
    );
  }

  final stored = Credential(
    uid: 'u1',
    passwordHash: testHasher.hash('correct-password'),
  );

  group('deleteByEmail', () {
    test('deletes the account when the password matches', () async {
      final result = await service(stored: stored).deleteByEmail(
        email: 'ada@example.com',
        password: 'correct-password',
      );

      expect(result, isA<AccountDeleted>());
      expect(users.deletedUid, 'u1');
    });

    test('rejects a wrong password without deleting', () async {
      final result = await service(stored: stored).deleteByEmail(
        email: 'ada@example.com',
        password: 'wrong-password',
      );

      expect(result, isA<AccountCredentialsRejected>());
      expect(users.deletedUid, isNull);
    });

    test('rejects an unknown email without deleting', () async {
      final result = await service().deleteByEmail(
        email: 'nobody@example.com',
        password: 'whatever',
      );

      expect(result, isA<AccountCredentialsRejected>());
      expect(users.deletedUid, isNull);
    });
  });

  group('deleteByUid', () {
    test('deletes the account when the password matches', () async {
      final result = await service(stored: stored).deleteByUid(
        uid: 'u1',
        password: 'correct-password',
      );

      expect(result, isA<AccountDeleted>());
      expect(users.deletedUid, 'u1');
    });

    test('rejects a wrong password without deleting', () async {
      final result = await service(stored: stored).deleteByUid(
        uid: 'u1',
        password: 'wrong-password',
      );

      expect(result, isA<AccountCredentialsRejected>());
      expect(users.deletedUid, isNull);
    });
  });
}
