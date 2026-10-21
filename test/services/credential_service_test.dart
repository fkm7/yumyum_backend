import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:yumyum_backend/auth/bcrypt_password_hasher.dart';
import 'package:yumyum_backend/models/credential.dart';
import 'package:yumyum_backend/services/credential_service.dart';

import '../helpers/fakes.dart';
import '../helpers/test_context.dart';

void main() {
  late StubCredentialRepository repository;

  CredentialService service({Credential? stored}) {
    repository = StubCredentialRepository(stored);
    return CredentialService(credentials: repository, hasher: testHasher);
  }

  Credential storedAs(String passwordHash) =>
      Credential(uid: 'u1', passwordHash: passwordHash);

  group('register', () {
    test('stores a bcrypt digest, never the plaintext', () async {
      final user = await service().register(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'ada@example.com',
        password: 'hunter2',
      );

      final digest = repository.credential!.passwordHash;
      expect(user, isNotNull);
      expect(digest, startsWith(r'$2a$'));
      expect(testHasher.verify('hunter2', digest), isTrue);
    });
  });

  group('verifyByEmail', () {
    test('returns the uid for a matching password', () async {
      final uid = await service(stored: storedAs(testHasher.hash('hunter2')))
          .verifyByEmail('ada@example.com', 'hunter2');

      expect(uid, equals('u1'));
    });

    test('returns null for a wrong password', () async {
      final uid = await service(stored: storedAs(testHasher.hash('hunter2')))
          .verifyByEmail('ada@example.com', 'wrong');

      expect(uid, isNull);
    });

    test('still hashes for an unknown email, to equalise timing', () async {
      final hasher = MockPasswordHasher();
      when(() => hasher.verifyAbsentUser(any())).thenReturn(null);

      final uid = await CredentialService(
        credentials: StubCredentialRepository(),
        hasher: hasher,
      ).verifyByEmail('nobody@example.com', 'hunter2');

      expect(uid, isNull);
      verify(() => hasher.verifyAbsentUser('hunter2')).called(1);
    });

    test('upgrades a legacy digest after a successful check', () async {
      await service(stored: storedAs(legacySha256Digest('hunter2')))
          .verifyByEmail('ada@example.com', 'hunter2');

      expect(repository.writtenHashes.single, startsWith(r'$2a$'));
    });

    test('never rewrites the digest after a failed check', () async {
      await service(stored: storedAs(legacySha256Digest('hunter2')))
          .verifyByEmail('ada@example.com', 'wrong');

      expect(repository.writtenHashes, isEmpty);
    });
  });

  group('verifyByUid', () {
    test('accepts the right password and rejects a wrong one', () async {
      final credentials = service(stored: storedAs(testHasher.hash('hunter2')));

      expect(await credentials.verifyByUid('u1', 'hunter2'), isTrue);
      expect(await credentials.verifyByUid('u1', 'wrong'), isFalse);
    });

    test('rejects an unknown uid', () async {
      expect(await service().verifyByUid('nobody', 'hunter2'), isFalse);
    });
  });

  group('setPassword', () {
    test('stores a digest of the new password', () async {
      final credentials =
          service(stored: storedAs(testHasher.hash('old-password')));

      await credentials.setPassword('u1', 'new-password');

      expect(await credentials.verifyByUid('u1', 'new-password'), isTrue);
      expect(await credentials.verifyByUid('u1', 'old-password'), isFalse);
    });
  });
}
