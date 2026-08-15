import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/bcrypt_password_hasher.dart';
import 'package:delmer_backend/auth/password_hasher.dart';
import 'package:delmer_backend/models/user.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../routes/auth/login.dart' as route;
import '../../helpers/test_context.dart';

User _user({String? passwordHash}) => User(
      uid: 'user-1',
      firstName: 'Ada',
      lastName: 'Lovelace',
      email: 'ada@example.com',
      photoUrl: '',
      passwordHash: passwordHash ?? testHasher.hash('hunter2'),
    );

MockUserRepository _repository({User? found}) {
  final repository = MockUserRepository();
  when(() => repository.findByEmail(any())).thenAnswer((_) async => found);
  when(() => repository.updatePasswordHash(any(), any()))
      .thenAnswer((_) async {});
  return repository;
}

Future<Response> _invoke(
  Request request, {
  User? found,
  MockUserRepository? repository,
  PasswordHasher? hasher,
}) {
  final context = TestContext(request: request)
    ..provide<UserRepository>(repository ?? _repository(found: found));
  if (hasher != null) context.provide<PasswordHasher>(hasher);
  return Future.value(context.context).then(route.onRequest);
}

Request _credentials({
  String email = 'ada@example.com',
  String password = 'hunter2',
}) =>
    jsonRequest('POST', body: {'email': email, 'password': password});

void main() {
  group('POST /auth/login', () {
    test('rejects every method except POST', () async {
      await expectMethodNotAllowed(_invoke, allowed: {'POST'});
    });

    test('responds 400 for a malformed JSON body', () async {
      final response = await _invoke(
        Request('POST', Uri.parse('http://localhost/'), body: 'not json'),
      );

      expect(response.statusCode, equals(400));
      expect(await jsonBody(response), equals({'error': 'Invalid JSON'}));
    });

    test('responds 422 when email or password is missing', () async {
      for (final body in [
        <String, dynamic>{},
        {'email': 'ada@example.com'},
        {'password': 'hunter2'},
      ]) {
        final response = await _invoke(jsonRequest('POST', body: body));
        expect(response.statusCode, equals(422));
      }
    });

    test('responds 401 for an unknown email', () async {
      expect((await _invoke(_credentials())).statusCode, equals(401));
    });

    test('responds 401 for a wrong password', () async {
      final response = await _invoke(
        _credentials(password: 'wrong'),
        found: _user(),
      );

      expect(response.statusCode, equals(401));
    });

    test('responds 401 when the stored digest is unreadable', () async {
      final response = await _invoke(
        _credentials(),
        found: _user(passwordHash: 'not-a-digest'),
      );

      expect(response.statusCode, equals(401));
    });

    // Anti-enumeration: the two failures must be indistinguishable, or the
    // endpoint tells an attacker which addresses are registered.
    test('answers identically for an unknown email and a wrong password',
        () async {
      final unknown = await _invoke(_credentials());
      final wrongPassword = await _invoke(
        _credentials(password: 'wrong'),
        found: _user(),
      );

      expect(unknown.statusCode, equals(wrongPassword.statusCode));
      expect(await jsonBody(unknown), equals(await jsonBody(wrongPassword)));
    });

    // bcrypt is deliberately slow, so bailing out early for an unknown address
    // would make it measurably faster to reject than a registered one. The
    // route has to do equivalent work on both paths.
    test('still hashes when no user matched, to equalise response time',
        () async {
      final hasher = MockPasswordHasher();
      when(() => hasher.verifyAbsentUser(any())).thenReturn(null);

      await _invoke(_credentials(), hasher: hasher);

      verify(() => hasher.verifyAbsentUser('hunter2')).called(1);
    });

    group('credential migration', () {
      // Existing rows hold unsalted SHA-256 and cannot be converted without
      // the plaintext, so a successful login is the only chance to upgrade.
      test('accepts a legacy SHA-256 digest', () async {
        final response = await _invoke(
          _credentials(),
          found: _user(passwordHash: legacySha256Digest('hunter2')),
        );

        expect(response.statusCode, equals(200));
      });

      test('rejects a wrong password against a legacy digest', () async {
        final response = await _invoke(
          _credentials(password: 'wrong'),
          found: _user(passwordHash: legacySha256Digest('hunter2')),
        );

        expect(response.statusCode, equals(401));
      });

      test('upgrades a legacy digest to bcrypt on successful login', () async {
        final repository = _repository(
          found: _user(passwordHash: legacySha256Digest('hunter2')),
        );

        await _invoke(_credentials(), repository: repository);

        final captured = verify(
          () => repository.updatePasswordHash('user-1', captureAny()),
        ).captured.single as String;

        expect(captured, startsWith(r'$2a$'));
        expect(testHasher.verify('hunter2', captured), isTrue);
        expect(testHasher.needsRehash(captured), isFalse);
      });

      test('does not rewrite a digest that is already current', () async {
        final repository = _repository(found: _user());

        await _invoke(_credentials(), repository: repository);

        verifyNever(() => repository.updatePasswordHash(any(), any()));
      });

      test('does not upgrade after a failed login', () async {
        final repository = _repository(
          found: _user(passwordHash: legacySha256Digest('hunter2')),
        );

        await _invoke(_credentials(password: 'wrong'), repository: repository);

        verifyNever(() => repository.updatePasswordHash(any(), any()));
      });

      test('upgrades a bcrypt digest hashed at a weaker cost', () async {
        final weak = BcryptPasswordHasher(rounds: 4).hash('hunter2');
        final repository = _repository(found: _user(passwordHash: weak));
        final stronger = BcryptPasswordHasher(rounds: 6);

        await _invoke(
          _credentials(),
          repository: repository,
          hasher: stronger,
        );

        final captured = verify(
          () => repository.updatePasswordHash('user-1', captureAny()),
        ).captured.single as String;

        expect(captured, startsWith(r'$2a$06$'));
      });
    });

    group('on success', () {
      Future<Map<String, dynamic>> body() async {
        final response = await _invoke(_credentials(), found: _user());
        expect(response.statusCode, equals(200));
        return await jsonBody(response) as Map<String, dynamic>;
      }

      test('returns an access token that verifies to the uid', () async {
        final json = await body();
        expect(
          testTokens.verifyAccessToken(json['access_token'] as String),
          equals('user-1'),
        );
      });

      test('returns a refresh token that verifies to the uid', () async {
        final json = await body();
        expect(
          testTokens.verifyRefreshToken(json['refresh_token'] as String),
          equals('user-1'),
        );
      });

      test('reports both token lifetimes in seconds', () async {
        final json = await body();
        expect(json['access_token_expires_in'], equals(86400));
        expect(json['refresh_token_expires_in'], equals(259200));
      });

      test('returns the user in snake_case', () async {
        final json = await body();
        expect(
          json['user'],
          equals({
            'uid': 'user-1',
            'first_name': 'Ada',
            'last_name': 'Lovelace',
            'email': 'ada@example.com',
            'photo_url': '',
          }),
        );
      });

      // The digest is loaded for the comparison, so the response is the place
      // it could leak.
      test('never leaks the password hash', () async {
        final user = _user();
        final response = await _invoke(_credentials(), found: user);
        final json = await jsonBody(response) as Map<String, dynamic>;

        expect(json.toString(), isNot(contains(user.passwordHash)));
        expect((json['user']! as Map).containsKey('password_hash'), isFalse);
      });
    });
  });
}
