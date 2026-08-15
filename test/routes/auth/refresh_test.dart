import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/token_service.dart';
import 'package:delmer_backend/models/user.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../routes/auth/refresh.dart' as route;
import '../../helpers/test_context.dart';

const _user = User(
  uid: 'user-1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  photoUrl: '',
);

Future<Response> _invoke(Request request, {User? found = _user}) {
  final repository = MockUserRepository();
  when(() => repository.findByUid(any())).thenAnswer((_) async => found);
  final context = TestContext(request: request)
    ..provide<UserRepository>(repository);
  return Future.value(context.context).then(route.onRequest);
}

void main() {
  final validToken = testTokens.generateRefreshToken('user-1');

  group('POST /auth/refresh', () {
    test('rejects every method except POST', () async {
      await expectMethodNotAllowed(_invoke, allowed: {'POST'});
    });

    test('responds 400 for a malformed JSON body', () async {
      final response = await _invoke(
        Request('POST', Uri.parse('http://localhost/'), body: 'nope'),
      );
      expect(response.statusCode, equals(400));
    });

    test('responds 422 when the token is missing or empty', () async {
      for (final body in [
        <String, dynamic>{},
        {'refreshToken': ''},
      ]) {
        final response = await _invoke(jsonRequest('POST', body: body));
        expect(response.statusCode, equals(422));
      }
    });

    // The route accepts both spellings; both are pinned so neither is dropped
    // by accident.
    for (final key in ['refreshToken', 'refresh_token']) {
      test('accepts the "$key" spelling', () async {
        final response = await _invoke(
          jsonRequest('POST', body: {key: validToken}),
        );
        expect(response.statusCode, equals(200));
      });
    }

    test('responds 401 for a garbage token', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'nonsense'}),
      );
      expect(response.statusCode, equals(401));
    });

    // An access token must not be usable to mint new tokens.
    test('responds 401 when given an access token', () async {
      final response = await _invoke(
        jsonRequest(
          'POST',
          body: {'refreshToken': testTokens.generateAccessToken('user-1')},
        ),
      );
      expect(response.statusCode, equals(401));
    });

    test('responds 401 for an expired refresh token', () async {
      const expired = TokenService(
        secret: 'test-secret',
        refreshTokenExpiresIn: Duration(seconds: -1),
      );
      final response = await _invoke(
        jsonRequest(
          'POST',
          body: {'refreshToken': expired.generateRefreshToken('user-1')},
        ),
      );
      expect(response.statusCode, equals(401));
    });

    test('responds 404 when the user no longer exists', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': validToken}),
        found: null,
      );
      expect(response.statusCode, equals(404));
    });

    test('issues a fresh pair of working tokens', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': validToken}),
      );
      final json = await jsonBody(response) as Map<String, dynamic>;

      expect(response.statusCode, equals(200));
      expect(
        testTokens.verifyAccessToken(json['access_token'] as String),
        equals('user-1'),
      );
      expect(
        testTokens.verifyRefreshToken(json['refresh_token'] as String),
        equals('user-1'),
      );
    });

    test('does not echo the user object', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': validToken}),
      );
      final json = await jsonBody(response) as Map<String, dynamic>;
      expect(json.containsKey('user'), isFalse);
    });

    // Documents current behaviour rather than endorsing it: without a
    // persisted token store the presented token stays valid after rotation.
    test('leaves the presented refresh token usable (no revocation yet)',
        () async {
      await _invoke(jsonRequest('POST', body: {'refreshToken': validToken}));
      final second = await _invoke(
        jsonRequest('POST', body: {'refreshToken': validToken}),
      );
      expect(second.statusCode, equals(200));
    });
  });
}
