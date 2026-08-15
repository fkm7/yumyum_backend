import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/bcrypt_password_hasher.dart';
import 'package:delmer_backend/models/user.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../routes/auth/register.dart' as route;
import '../../helpers/test_context.dart';

const _created = User(
  uid: 'user-1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  photoUrl: '',
);

const _validBody = {
  'first_name': 'Ada',
  'last_name': 'Lovelace',
  'email': 'ada@example.com',
  'password': 'hunter2',
};

MockUserRepository _repository({User? returns = _created}) {
  final repository = MockUserRepository();
  when(
    () => repository.create(
      firstName: any(named: 'firstName'),
      lastName: any(named: 'lastName'),
      email: any(named: 'email'),
      passwordHash: any(named: 'passwordHash'),
    ),
  ).thenAnswer((_) async => returns);
  return repository;
}

Future<Response> _invoke(Request request, {MockUserRepository? repository}) {
  final context = TestContext(request: request)
    ..provide<UserRepository>(repository ?? _repository());
  return Future.value(context.context).then(route.onRequest);
}

void main() {
  group('POST /auth/register', () {
    test('rejects every method except POST', () async {
      await expectMethodNotAllowed(_invoke, allowed: {'POST'});
    });

    test('responds 400 for a malformed JSON body', () async {
      final response = await _invoke(
        Request('POST', Uri.parse('http://localhost/'), body: '{'),
      );

      expect(response.statusCode, equals(400));
    });

    test('responds 422 when any required field is missing', () async {
      for (final missing in _validBody.keys) {
        final body = Map<String, dynamic>.from(_validBody)..remove(missing);
        final response = await _invoke(jsonRequest('POST', body: body));
        expect(
          response.statusCode,
          equals(422),
          reason: 'missing $missing should be rejected',
        );
      }
    });

    test('responds 409 when the email is already registered', () async {
      final response = await _invoke(
        jsonRequest('POST', body: _validBody),
        repository: _repository(returns: null),
      );

      expect(response.statusCode, equals(409));
      expect(
        await jsonBody(response),
        equals({'error': 'Email already registered'}),
      );
    });

    test('stores the password as a digest, never as plaintext', () async {
      final repository = _repository();
      await _invoke(
        jsonRequest('POST', body: _validBody),
        repository: repository,
      );

      final captured = verify(
        () => repository.create(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          email: any(named: 'email'),
          passwordHash: captureAny(named: 'passwordHash'),
        ),
      ).captured.single;

      // Stored digests must be salted bcrypt, not the plaintext and not the
      // old unsalted SHA-256.
      expect(
        captured,
        isA<String>().having((h) => h, 'digest', startsWith(r'$2a$')),
      );
      expect(captured, isNot(equals('hunter2')));
      expect(captured, isNot(equals(legacySha256Digest('hunter2'))));
      expect(testHasher.verify('hunter2', captured as String), isTrue);
    });

    test('responds 201 with tokens and the created user', () async {
      final response = await _invoke(jsonRequest('POST', body: _validBody));
      final json = await jsonBody(response) as Map<String, dynamic>;

      expect(response.statusCode, equals(201));
      expect(
        testTokens.verifyAccessToken(json['access_token'] as String),
        equals('user-1'),
      );
      expect(
        testTokens.verifyRefreshToken(json['refresh_token'] as String)?.uid,
        equals('user-1'),
      );
      expect(json['user'], equals(_created.toJson()));
    });

    test('never leaks a password hash in the response', () async {
      final response = await _invoke(jsonRequest('POST', body: _validBody));
      final json = await jsonBody(response) as Map<String, dynamic>;

      expect((json['user']! as Map).containsKey('password_hash'), isFalse);
      expect(json.toString(), isNot(contains(r'$2a$')));
    });
  });
}
