import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/models/user.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';

import '../../../routes/api/v1/user/me/index.dart' as route;
import '../../helpers/test_context.dart';

const _user = User(
  uid: 'user-1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  photoUrl: 'https://example.com/ada.png',
);

Future<Response> _invoke({String? authorization, User? found = _user}) {
  final repository = MockUserRepository();
  when(() => repository.findByUid(any())).thenAnswer((_) async => found);

  final context = TestContext(
    request: jsonRequest(
      'GET',
      headers: authorization == null ? null : {'Authorization': authorization},
    ),
  )..provide<UserRepository>(repository);

  return Future.value(context.context).then(route.onRequest);
}

String get _validToken => testTokens.generateAccessToken('user-1');

void main() {
  group('GET /auth/me', () {
    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(
        (request) {
          final repository = MockUserRepository();
          when(() => repository.findByUid(any()))
              .thenAnswer((_) async => _user);
          final context = TestContext(request: request)
            ..provide<UserRepository>(repository);
          return Future.value(context.context).then(route.onRequest);
        },
        allowed: {'GET'},
      );
    });

    group('responds 401', () {
      test('with no Authorization header', () async {
        expect((await _invoke()).statusCode, equals(401));
      });

      test('with a non-Bearer scheme', () async {
        final response = await _invoke(authorization: 'Basic abc123');
        expect(response.statusCode, equals(401));
      });

      test('with a Bearer prefix but no token', () async {
        expect((await _invoke(authorization: 'Bearer ')).statusCode, 401);
      });

      test('with a garbage token', () async {
        final response = await _invoke(authorization: 'Bearer nonsense');
        expect(response.statusCode, equals(401));
      });

      test('with a refresh token instead of an access token', () async {
        final refresh =
            testTokens.generateRefreshToken('user-1', tokenId: 'jti-1');
        final response = await _invoke(authorization: 'Bearer $refresh');
        expect(response.statusCode, equals(401));
      });

      test('with an expired access token', () async {
        const expired = TokenService(
          secret: 'test-secret',
          accessTokenExpiresIn: Duration(seconds: -1),
        );
        final response = await _invoke(
          authorization: 'Bearer ${expired.generateAccessToken('user-1')}',
        );
        expect(response.statusCode, equals(401));
      });

      test('with a token signed by a different secret', () async {
        const attacker = TokenService(secret: 'other-secret');
        final response = await _invoke(
          authorization: 'Bearer ${attacker.generateAccessToken('user-1')}',
        );
        expect(response.statusCode, equals(401));
      });
    });

    // RFC 7235 defines the auth scheme as case-insensitive; the previous
    // `startsWith('Bearer ')` check rejected a lowercase scheme.
    test('accepts a lowercase bearer scheme', () async {
      final response = await _invoke(authorization: 'bearer $_validToken');
      expect(response.statusCode, equals(200));
    });

    test('responds 404 when the token is valid but the user is gone', () async {
      final response = await _invoke(
        authorization: 'Bearer $_validToken',
        found: null,
      );

      expect(response.statusCode, equals(404));
      expect(await jsonBody(response), equals({'error': 'User not found'}));
    });

    test('responds 200 with the user in snake_case', () async {
      final response = await _invoke(authorization: 'Bearer $_validToken');

      expect(response.statusCode, equals(200));
      expect(
        await jsonBody(response),
        equals({
          'uid': 'user-1',
          'first_name': 'Ada',
          'last_name': 'Lovelace',
          'email': 'ada@example.com',
          'photo_url': 'https://example.com/ada.png',
        }),
      );
    });

    test('looks the user up by the uid carried in the token', () async {
      final repository = MockUserRepository();
      when(() => repository.findByUid(any())).thenAnswer((_) async => _user);

      final context = TestContext(
        request: jsonRequest(
          'GET',
          headers: {
            'Authorization': 'Bearer ${testTokens.generateAccessToken('abc')}',
          },
        ),
      )..provide<UserRepository>(repository);

      await route.onRequest(context.context);

      verify(() => repository.findByUid('abc')).called(1);
    });
  });
}
